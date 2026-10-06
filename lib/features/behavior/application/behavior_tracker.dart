import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/json_int64.dart';
import '../../auth/application/auth_notifier.dart';
import '../../feed/data/feed_models.dart';
import '../data/behavior_event.dart';
import '../data/behavior_event_queue.dart';
import '../data/behavior_identity.dart';
import '../data/behavior_repository.dart';

// 已上报曝光的去重键列表在本地偏好中的存储键。
const _exposureDedupeStorageKey = 'behavior.exposure_dedupe.v1';

/// 推荐场景的行为埋点入口，供 Feed 卡片、广告位与详情页上报曝光、点击、隐藏与停留。
/// 事件只进入本地持久队列，由队列负责批量发送与重试；页面调用不会因网络失败而抛错。
abstract interface class BehaviorTracker {
  /// 恢复持久化的队列与曝光去重键；可重复调用，只执行一次。
  Future<void> initialize();

  /// 上报曝光；同一推荐请求内同一目标只记一次，返回本次是否真正入队。
  Future<bool> trackExposure(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  /// 上报点击。
  Future<void> trackClick(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  /// 上报隐藏。
  Future<void> trackHide(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  /// 上报帖子停留时长；非正时长忽略。
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  );
}

/// [BehaviorTracker] 的默认实现：事件归属到当前会话身份后写入 [BehaviorEventEnqueuer]；
/// 曝光去重键持久化并只保留最近 [maxExposureKeys] 条，重启后不会重复上报同一曝光。
class PersistentBehaviorTracker implements BehaviorTracker {
  final BehaviorEventEnqueuer _queue;
  final ClientIdentityStore _identityStore;
  final Future<SharedPreferences> Function() _preferences;
  final int Function() _nowMilliseconds;
  final int maxExposureKeys;

  final List<String> _exposureKeys = [];
  final Set<String> _exposureKeySet = {};
  Future<void> _serial = Future.value();
  Future<void>? _initializing;

  PersistentBehaviorTracker({
    required BehaviorEventEnqueuer queue,
    required ClientIdentityStore identityStore,
    Future<SharedPreferences> Function()? preferences,
    int Function()? nowMilliseconds,
    this.maxExposureKeys = 2000,
  }) : assert(maxExposureKeys > 0),
       _queue = queue,
       _identityStore = identityStore,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _nowMilliseconds =
           nowMilliseconds ?? (() => DateTime.now().millisecondsSinceEpoch);

  @override
  Future<void> initialize() {
    return _initializing ??= _initialize();
  }

  @override
  Future<bool> trackExposure(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async {
    // 推荐上下文不完整或无法确定事件归属（令牌解不出用户）时不上报。
    if (!_valid(targetId, context)) return false;
    final owner = await loadBehaviorIdentity();
    if (owner.ownerIdentity == null) return false;
    await initialize();
    final dedupeKey = exposureDedupeKey(
      context.requestId,
      targetType,
      targetId,
    );
    // 去重判断、入队与记录去重键串行执行，避免并发曝光重复入队；
    // clientEventId 由去重键派生，同一曝光无论重试几次都使用同一事件 ID。
    return _synchronized(() async {
      if (_exposureKeySet.contains(dedupeKey)) return false;
      await _enqueue(
        action: 'exposure',
        targetId: targetId,
        targetType: targetType,
        context: context,
        clientEventId: 'exposure-$dedupeKey',
        ownerIdentity: owner.ownerIdentity!,
      );
      // 超出上限时按先进先出淘汰最旧的键。
      _exposureKeys.add(dedupeKey);
      _exposureKeySet.add(dedupeKey);
      while (_exposureKeys.length > maxExposureKeys) {
        _exposureKeySet.remove(_exposureKeys.removeAt(0));
      }
      await _persistExposureKeys();
      return true;
    });
  }

  @override
  Future<void> trackClick(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) {
    return _track('click', targetId, targetType, context);
  }

  @override
  Future<void> trackHide(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) {
    return _track('hide', targetId, targetType, context);
  }

  @override
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  ) async {
    if (duration.inMilliseconds <= 0 || !_valid(postId, context)) return;
    final owner = await loadBehaviorIdentity();
    if (owner.ownerIdentity == null) return;
    await initialize();
    await _enqueue(
      action: 'dwell',
      targetId: postId,
      targetType: behaviorTargetPost,
      context: context,
      durationMs: duration.inMilliseconds,
      ownerIdentity: owner.ownerIdentity!,
    );
  }

  // 点击、隐藏等无需去重的事件的公共入队流程。
  Future<void> _track(
    String action,
    Object targetId,
    String targetType,
    FeedRecommendationContext context,
  ) async {
    if (!_valid(targetId, context)) return;
    final owner = await loadBehaviorIdentity();
    if (owner.ownerIdentity == null) return;
    await initialize();
    await _enqueue(
      action: action,
      targetId: targetId,
      targetType: targetType,
      context: context,
      ownerIdentity: owner.ownerIdentity!,
    );
  }

  // 只上报带完整推荐上下文（请求 ID、场景、从 1 开始的位置）的有效目标。
  bool _valid(Object targetId, FeedRecommendationContext context) {
    return jsonInt64IsPositive(targetId) &&
        context.requestId.isNotEmpty &&
        context.scene.isNotEmpty &&
        context.position > 0;
  }

  // 组装事件：附上客户端身份、发生时间与推荐解释字段后入队。
  Future<void> _enqueue({
    required String action,
    required Object targetId,
    required String targetType,
    required FeedRecommendationContext context,
    required String ownerIdentity,
    String? clientEventId,
    int? durationMs,
  }) async {
    final identity = await _identityStore.loadOrCreate();
    await _queue.enqueue(
      QueuedBehaviorEvent(
        ownerIdentity: ownerIdentity,
        anonymousId: identity.anonymousId,
        sessionId: identity.sessionId,
        event: ClientBehaviorEvent(
          clientEventId: clientEventId ?? _identityStore.createEventId(),
          occurredAt: _nowMilliseconds(),
          action: action,
          targetId: targetId,
          targetType: targetType,
          scene: context.scene,
          requestId: context.requestId,
          position: context.position,
          durationMs: durationMs,
          recallSource: context.recallSource,
          modelVersion: context.modelVersion,
          experimentId: context.experimentId,
        ),
      ),
    );
  }

  // 先恢复队列，再载入曝光去重键：旧格式键迁移为新格式、超限部分截掉，
  // 有变化时写回；存储内容损坏时直接丢弃。
  Future<void> _initialize() async {
    await _queue.initialize();
    final preferences = await _preferences();
    final encoded = preferences.getString(_exposureDedupeStorageKey);
    if (encoded == null || encoded.isEmpty) return;
    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      final stored = decoded
          .whereType<String>()
          .where((key) => key.isNotEmpty)
          .toList();
      final keys = stored.map(migrateExposureDedupeKey).toList();
      final migrated = stored.indexed.any(
        (indexed) => indexed.$2 != keys[indexed.$1],
      );
      final start = keys.length > maxExposureKeys
          ? keys.length - maxExposureKeys
          : 0;
      for (final key in keys.skip(start)) {
        if (_exposureKeySet.add(key)) _exposureKeys.add(key);
      }
      if (start > 0 || migrated) {
        await _persistExposureKeys();
      }
    } catch (_) {
      await preferences.remove(_exposureDedupeStorageKey);
    }
  }

  // 按插入顺序保存去重键，重启后淘汰顺序不变。
  Future<void> _persistExposureKeys() async {
    final preferences = await _preferences();
    await preferences.setString(
      _exposureDedupeStorageKey,
      jsonEncode(_exposureKeys),
    );
  }

  // 把操作串到同一条队尾依次执行，单个失败只反馈给它的调用方。
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
}

/// 曝光去重键 `<requestId>:<targetType>:<targetId>`（FX-104）。
String exposureDedupeKey(
  String requestId,
  String targetType,
  Object targetId,
) => '$requestId:$targetType:${jsonInt64Id(targetId)}';

/// 升级前持久化的两段键 `<requestId>:<postId>` 按帖子解释，避免重复上报帖子曝光。
String migrateExposureDedupeKey(String key) {
  final parts = key.split(':');
  if (parts.length != 2) return key;
  return '${parts[0]}:$behaviorTargetPost:${parts[1]}';
}

/// 行为事件的发送通道，测试可替换为假实现。
final behaviorEventTransportProvider = Provider<BehaviorEventTransport>((ref) {
  return const BehaviorRepository();
});

/// 全局行为事件队列；会话身份变化时立即尝试发送，让新身份名下的积压事件尽快发出。
final behaviorEventQueueProvider = Provider<BehaviorEventQueue>((ref) {
  final queue = BehaviorEventQueue(
    transport: ref.read(behaviorEventTransportProvider),
  );
  ref.onDispose(queue.dispose);
  ref.listen(authSessionIdentityProvider, (_, _) {
    unawaited(queue.flush());
  });
  return queue;
});

/// 页面使用的埋点入口。
final behaviorTrackerProvider = Provider<BehaviorTracker>((ref) {
  return PersistentBehaviorTracker(
    queue: ref.read(behaviorEventQueueProvider),
    identityStore: ref.read(clientIdentityStoreProvider),
  );
});

/// 应用启动时由根组件 watch，提前恢复队列并发送上次未送达的事件。
final behaviorInitializationProvider = FutureProvider<void>((ref) {
  return ref.read(behaviorTrackerProvider).initialize();
});
