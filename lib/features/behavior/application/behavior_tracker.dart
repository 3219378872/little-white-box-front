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

const _exposureDedupeStorageKey = 'behavior.exposure_dedupe.v1';

abstract interface class BehaviorTracker {
  Future<void> initialize();

  Future<bool> trackExposure(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  Future<void> trackClick(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  Future<void> trackHide(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  });

  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  );
}

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
    if (!_valid(targetId, context)) return false;
    final owner = await loadBehaviorIdentity();
    if (owner.ownerIdentity == null) return false;
    await initialize();
    final dedupeKey = exposureDedupeKey(
      context.requestId,
      targetType,
      targetId,
    );
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

  bool _valid(Object targetId, FeedRecommendationContext context) {
    return jsonInt64IsPositive(targetId) &&
        context.requestId.isNotEmpty &&
        context.scene.isNotEmpty &&
        context.position > 0;
  }

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

  Future<void> _persistExposureKeys() async {
    final preferences = await _preferences();
    await preferences.setString(
      _exposureDedupeStorageKey,
      jsonEncode(_exposureKeys),
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

final behaviorEventTransportProvider = Provider<BehaviorEventTransport>((ref) {
  return const BehaviorRepository();
});

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

final behaviorTrackerProvider = Provider<BehaviorTracker>((ref) {
  return PersistentBehaviorTracker(
    queue: ref.read(behaviorEventQueueProvider),
    identityStore: ref.read(clientIdentityStoreProvider),
  );
});

final behaviorInitializationProvider = FutureProvider<void>((ref) {
  return ref.read(behaviorTrackerProvider).initialize();
});
