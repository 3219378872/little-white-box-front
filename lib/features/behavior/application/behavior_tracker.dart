import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/json_int64.dart';
import '../../feed/data/feed_models.dart';
import '../data/behavior_event.dart';
import '../data/behavior_event_queue.dart';
import '../data/behavior_repository.dart';

const _exposureDedupeStorageKey = 'behavior.exposure_dedupe.v1';

abstract interface class BehaviorTracker {
  Future<void> initialize();

  Future<bool> trackExposure(Object postId, FeedRecommendationContext context);

  Future<void> trackClick(Object postId, FeedRecommendationContext context);

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
    Object postId,
    FeedRecommendationContext context,
  ) async {
    if (!_valid(postId, context)) return false;
    await initialize();
    final dedupeKey = '${context.requestId}:${jsonInt64Id(postId)}';
    return _synchronized(() async {
      if (_exposureKeySet.contains(dedupeKey)) return false;
      await _enqueue(
        action: 'exposure',
        postId: postId,
        context: context,
        clientEventId: 'exposure-$dedupeKey',
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
  Future<void> trackClick(Object postId, FeedRecommendationContext context) {
    return _track('click', postId, context);
  }

  @override
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  ) async {
    if (duration.inMilliseconds <= 0 || !_valid(postId, context)) return;
    await initialize();
    await _enqueue(
      action: 'dwell',
      postId: postId,
      context: context,
      durationMs: duration.inMilliseconds,
    );
  }

  Future<void> _track(
    String action,
    Object postId,
    FeedRecommendationContext context,
  ) async {
    if (!_valid(postId, context)) return;
    await initialize();
    await _enqueue(action: action, postId: postId, context: context);
  }

  bool _valid(Object postId, FeedRecommendationContext context) {
    return jsonInt64IsPositive(postId) &&
        context.requestId.isNotEmpty &&
        context.scene.isNotEmpty &&
        context.position > 0;
  }

  Future<void> _enqueue({
    required String action,
    required Object postId,
    required FeedRecommendationContext context,
    String? clientEventId,
    int? durationMs,
  }) async {
    final identity = await _identityStore.loadOrCreate();
    await _queue.enqueue(
      QueuedBehaviorEvent(
        anonymousId: identity.anonymousId,
        sessionId: identity.sessionId,
        event: ClientBehaviorEvent(
          clientEventId: clientEventId ?? _identityStore.createEventId(),
          occurredAt: _nowMilliseconds(),
          action: action,
          targetId: postId,
          targetType: 'post',
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
      final keys = decoded
          .whereType<String>()
          .where((key) => key.isNotEmpty)
          .toList();
      final start = keys.length > maxExposureKeys
          ? keys.length - maxExposureKeys
          : 0;
      for (final key in keys.skip(start)) {
        if (_exposureKeySet.add(key)) _exposureKeys.add(key);
      }
      if (start > 0) await _persistExposureKeys();
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

final behaviorEventTransportProvider = Provider<BehaviorEventTransport>((ref) {
  return const BehaviorRepository();
});

final behaviorEventQueueProvider = Provider<BehaviorEventQueue>((ref) {
  final queue = BehaviorEventQueue(
    transport: ref.read(behaviorEventTransportProvider),
  );
  ref.onDispose(queue.dispose);
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
