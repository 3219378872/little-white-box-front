import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'behavior_event.dart';
import 'behavior_identity.dart';
import 'behavior_repository.dart';

// 待发送事件在本地偏好中的存储键。
const _queueStorageKey = 'behavior.event_queue.v1';

/// 网络连通性来源，供队列在离线时暂停发送、恢复时立即补发；测试可替换。
abstract interface class ConnectivityMonitor {
  Future<bool> get isOnline;
  Stream<bool> get onStatusChanged;
}

/// 埋点入口依赖的入队能力，与发送调度解耦以便测试。
abstract interface class BehaviorEventEnqueuer {
  /// 恢复持久化的待发送事件；可重复调用，只执行一次。
  Future<void> initialize();

  /// 持久化一条事件并安排发送。
  Future<void> enqueue(QueuedBehaviorEvent event);
}

/// 基于 connectivity_plus 的连通性实现：任一网络接口可用即视为在线。
class PluginConnectivityMonitor implements ConnectivityMonitor {
  final Connectivity _connectivity;

  PluginConnectivityMonitor({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  @override
  Future<bool> get isOnline async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  @override
  Stream<bool> get onStatusChanged => _connectivity.onConnectivityChanged.map(
    (results) => !results.contains(ConnectivityResult.none),
  );
}

/// 持久化的行为事件队列：入队后延迟 [flushDelay] 合批发送，失败按指数退避重试
/// （[baseRetryDelay] 起、不超过 [maxRetryDelay]），离线暂停、恢复联网立即补发。
/// 队列最多保留 [maxQueueSize] 条，超出时丢弃最旧的事件；只发送归属于当前会话身份的事件。
class BehaviorEventQueue implements BehaviorEventEnqueuer {
  final BehaviorEventTransport _transport;
  final ConnectivityMonitor _connectivity;
  final Future<SharedPreferences> Function() _preferences;
  final Future<BehaviorIdentity> Function() _loadIdentity;
  final int maxQueueSize;
  final int maxBatchSize;
  final Duration flushDelay;
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final bool autoFlush;

  final List<QueuedBehaviorEvent> _events = [];
  Future<void> _serial = Future.value();
  Future<void>? _initializing;
  StreamSubscription<bool>? _connectivitySubscription;
  Timer? _flushTimer;
  bool _online = true;
  bool _flushInFlight = false;
  bool _disposed = false;
  int _retryAttempt = 0;

  BehaviorEventQueue({
    required BehaviorEventTransport transport,
    ConnectivityMonitor? connectivity,
    Future<SharedPreferences> Function()? preferences,
    Future<BehaviorIdentity> Function()? loadIdentity,
    this.maxQueueSize = 500,
    this.maxBatchSize = 100,
    this.flushDelay = const Duration(milliseconds: 500),
    this.baseRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(minutes: 1),
    this.autoFlush = true,
  }) : assert(maxQueueSize > 0),
       assert(maxBatchSize > 0 && maxBatchSize <= 100),
       _transport = transport,
       _loadIdentity = loadIdentity ?? loadBehaviorIdentity,
       _connectivity = connectivity ?? PluginConnectivityMonitor(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  /// 待发送事件数。
  int get pendingCount => _events.length;

  /// 待发送事件的只读快照。
  List<QueuedBehaviorEvent> get pendingEvents => List.unmodifiable(_events);

  /// Legacy events have no trustworthy account attribution and stay unsent.
  int get unattributedCount =>
      _events.where((event) => event.ownerIdentity == null).length;

  @override
  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  @override
  Future<void> enqueue(QueuedBehaviorEvent queuedEvent) async {
    await initialize();
    // 同一 clientEventId 只入队一次；超出容量时丢弃最旧的事件后落盘。
    await _synchronized(() async {
      if (_events.any(
        (item) => item.event.clientEventId == queuedEvent.event.clientEventId,
      )) {
        return;
      }
      _events.add(queuedEvent);
      if (_events.length > maxQueueSize) {
        _events.removeRange(0, _events.length - maxQueueSize);
      }
      await _persist();
    });
    if (autoFlush) _scheduleFlush(flushDelay);
  }

  /// 发送一批事件：取当前会话身份名下、与首条同一匿名/会话 ID 的最多 [maxBatchSize] 条；
  /// 已受理与永久拒绝的事件出队，其余保留并按退避重试。同一时刻只有一个批次在途。
  Future<void> flush() async {
    await initialize();
    if (_disposed || !_online) return;
    final identity = await _loadIdentity();
    if (_disposed || identity.ownerIdentity == null) return;

    final batchItems = await _synchronized<List<QueuedBehaviorEvent>>(() async {
      if (_flushInFlight || _events.isEmpty || !_online) return const [];
      final eligible = _events.where(
        (item) => item.ownerIdentity == identity.ownerIdentity,
      );
      if (eligible.isEmpty) return const [];
      _flushInFlight = true;
      final first = eligible.first;
      return eligible
          .where(
            (item) =>
                item.anonymousId == first.anonymousId &&
                item.sessionId == first.sessionId,
          )
          .take(maxBatchSize)
          .toList();
    });
    if (batchItems.isEmpty) return;

    try {
      final result = await _transport.send(
        BehaviorBatch(
          ownerIdentity: batchItems.first.ownerIdentity,
          anonymousId: batchItems.first.anonymousId,
          sessionId: batchItems.first.sessionId,
          events: batchItems.map((item) => item.event).toList(),
        ),
      );
      // 只移除本批中有终态结果的事件。
      final batchEventIds = batchItems
          .map((item) => item.event.clientEventId)
          .toSet();
      final terminal = result.terminalEventIds.intersection(batchEventIds);
      await _synchronized(() async {
        if (terminal.isNotEmpty) {
          _events.removeWhere(
            (item) => terminal.contains(item.event.clientEventId),
          );
          await _persist();
        }
        _flushInFlight = false;
      });

      // 本批全部终结且还有积压时立即发下一批；有事件未终结则退避重试。
      if (_events.isEmpty) {
        _retryAttempt = 0;
      } else if (terminal.length == batchItems.length) {
        _retryAttempt = 0;
        _scheduleFlush(Duration.zero);
      } else {
        _scheduleRetry();
      }
    } catch (_) {
      await _synchronized(() async => _flushInFlight = false);
      _scheduleRetry();
    }
  }

  /// 停止计时器与连通性监听；已持久化的事件保留到下次启动。
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

  // 恢复持久化的事件（损坏则清空），再订阅连通性变化：离线取消待发计时，
  // 恢复联网时重置退避并立即发送。
  Future<void> _initialize() async {
    final preferences = await _preferences();
    final encoded = preferences.getString(_queueStorageKey);
    if (encoded != null && encoded.isNotEmpty) {
      try {
        final decoded = jsonDecode(encoded) as List<dynamic>;
        _events
          ..clear()
          ..addAll(
            decoded
                .whereType<Map>()
                .map(
                  (item) => QueuedBehaviorEvent.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.event.clientEventId.isNotEmpty),
          );
        if (_events.length > maxQueueSize) {
          _events.removeRange(0, _events.length - maxQueueSize);
          await _persist();
        }
      } catch (_) {
        _events.clear();
        await preferences.remove(_queueStorageKey);
      }
    }

    _online = await _connectivity.isOnline;
    _connectivitySubscription = _connectivity.onStatusChanged.listen((online) {
      _online = online;
      if (!online) {
        _flushTimer?.cancel();
        return;
      }
      _retryAttempt = 0;
      _scheduleFlush(Duration.zero);
    });
    if (_online && _events.isNotEmpty && autoFlush) {
      _scheduleFlush(Duration.zero);
    }
  }

  // 把整个队列写回本地偏好。
  Future<void> _persist() async {
    final preferences = await _preferences();
    await preferences.setString(
      _queueStorageKey,
      jsonEncode(_events.map((item) => item.toJson()).toList()),
    );
  }

  // 把队列读写串到同一条队尾依次执行，单个失败只反馈给它的调用方。
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serial = _serial.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  // 以 baseRetryDelay × 2^尝试次数 退避，并限制在 [baseRetryDelay, maxRetryDelay] 内。
  void _scheduleRetry() {
    final multiplier = 1 << _retryAttempt.clamp(0, 20);
    final milliseconds = baseRetryDelay.inMilliseconds * multiplier;
    final bounded = Duration(
      milliseconds: milliseconds.clamp(
        baseRetryDelay.inMilliseconds,
        maxRetryDelay.inMilliseconds,
      ),
    );
    _retryAttempt++;
    _scheduleFlush(bounded);
  }

  // 安排一次发送，覆盖之前的计时；离线或已销毁时不安排，关闭自动发送时只允许立即发送。
  void _scheduleFlush(Duration delay) {
    if (_disposed || !_online || !autoFlush && delay != Duration.zero) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }
}
