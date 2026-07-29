import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'behavior_event.dart';
import 'behavior_repository.dart';

const _queueStorageKey = 'behavior.event_queue.v1';

abstract interface class ConnectivityMonitor {
  Future<bool> get isOnline;
  Stream<bool> get onStatusChanged;
}

abstract interface class BehaviorEventEnqueuer {
  Future<void> initialize();

  Future<void> enqueue(QueuedBehaviorEvent event);
}

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

class BehaviorEventQueue implements BehaviorEventEnqueuer {
  final BehaviorEventTransport _transport;
  final ConnectivityMonitor _connectivity;
  final Future<SharedPreferences> Function() _preferences;
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
    this.maxQueueSize = 500,
    this.maxBatchSize = 100,
    this.flushDelay = const Duration(milliseconds: 500),
    this.baseRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(minutes: 1),
    this.autoFlush = true,
  }) : assert(maxQueueSize > 0),
       assert(maxBatchSize > 0 && maxBatchSize <= 100),
       _transport = transport,
       _connectivity = connectivity ?? PluginConnectivityMonitor(),
       _preferences = preferences ?? SharedPreferences.getInstance;

  int get pendingCount => _events.length;

  List<QueuedBehaviorEvent> get pendingEvents => List.unmodifiable(_events);

  @override
  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  @override
  Future<void> enqueue(QueuedBehaviorEvent queuedEvent) async {
    await initialize();
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

  Future<void> flush() async {
    await initialize();
    if (_disposed || !_online) return;

    final batchItems = await _synchronized<List<QueuedBehaviorEvent>>(() async {
      if (_flushInFlight || _events.isEmpty || !_online) return const [];
      _flushInFlight = true;
      final first = _events.first;
      return _events
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
          anonymousId: batchItems.first.anonymousId,
          sessionId: batchItems.first.sessionId,
          events: batchItems.map((item) => item.event).toList(),
        ),
      );
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

  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _connectivitySubscription?.cancel();
  }

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

  Future<void> _persist() async {
    final preferences = await _preferences();
    await preferences.setString(
      _queueStorageKey,
      jsonEncode(_events.map((item) => item.toJson()).toList()),
    );
  }

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

  void _scheduleFlush(Duration delay) {
    if (_disposed || !_online || !autoFlush && delay != Duration.zero) return;
    _flushTimer?.cancel();
    _flushTimer = Timer(delay, () {
      _flushTimer = null;
      unawaited(flush());
    });
  }
}
