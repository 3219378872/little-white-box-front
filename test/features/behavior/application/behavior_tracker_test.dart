import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/features/behavior/application/behavior_tracker.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event_queue.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('deduplicates exposure persistently by request and post', () async {
    final firstQueue = _RecordingQueue();
    final first = _tracker(firstQueue);

    expect(await first.trackExposure(7, context), isTrue);
    expect(await first.trackExposure(7, context), isFalse);
    expect(firstQueue.events, hasLength(1));
    expect(firstQueue.events.single.event.action, 'exposure');
    expect(firstQueue.events.single.event.durationMs, isNull);

    final restoredQueue = _RecordingQueue();
    final restored = _tracker(restoredQueue);
    expect(await restored.trackExposure(7, context), isFalse);
    expect(restoredQueue.events, isEmpty);
  });

  test(
    'records dwell separately with duration and recommendation context',
    () async {
      final queue = _RecordingQueue();
      final behaviorTracker = _tracker(queue);

      await behaviorTracker.trackClick(9, context);
      await behaviorTracker.trackDwell(
        9,
        context,
        const Duration(milliseconds: 1350),
      );

      expect(queue.events.map((item) => item.event.action), ['click', 'dwell']);
      final dwell = queue.events[1].event;
      expect(dwell.durationMs, 1350);
      expect(dwell.requestId, 'request-1');
      expect(dwell.position, 3);
      expect(dwell.recallSource, 'itemcf');
      expect(dwell.modelVersion, 'rank-v1');
      expect(dwell.experimentId, 'exp-a');
    },
  );

  test('ads are tracked with their own target type and dedupe key', () async {
    final queue = _RecordingQueue();
    final behaviorTracker = _tracker(queue);

    expect(await behaviorTracker.trackExposure(7, context), isTrue);
    expect(
      await behaviorTracker.trackExposure(
        7,
        context,
        targetType: behaviorTargetAd,
      ),
      isTrue,
    );
    expect(
      await behaviorTracker.trackExposure(
        7,
        context,
        targetType: behaviorTargetAd,
      ),
      isFalse,
    );
    await behaviorTracker.trackClick(7, context, targetType: behaviorTargetAd);
    await behaviorTracker.trackHide(7, context, targetType: behaviorTargetAd);

    expect(
      queue.events.map(
        (item) => '${item.event.action}:${item.event.targetType}',
      ),
      ['exposure:post', 'exposure:ad', 'click:ad', 'hide:ad'],
    );
    expect(queue.events[1].event.clientEventId, 'exposure-request-1:ad:7');
    expect(queue.events[1].event.requestId, 'request-1');
    expect(queue.events[1].event.position, 3);
  });

  test('legacy two-part exposure keys are read as post keys', () async {
    SharedPreferences.setMockInitialValues({
      'behavior.exposure_dedupe.v1': '["request-1:7"]',
    });
    final queue = _RecordingQueue();
    final behaviorTracker = _tracker(queue);

    expect(await behaviorTracker.trackExposure(7, context), isFalse);
    expect(
      await behaviorTracker.trackExposure(
        7,
        context,
        targetType: behaviorTargetAd,
      ),
      isTrue,
    );
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences.getString('behavior.exposure_dedupe.v1'),
      '["request-1:post:7","request-1:ad:7"]',
    );
  });

  test('dedupe key migration keeps already migrated keys', () {
    expect(migrateExposureDedupeKey('r:9'), 'r:post:9');
    expect(migrateExposureDedupeKey('r:ad:9'), 'r:ad:9');
    expect(exposureDedupeKey('r', behaviorTargetAd, '12'), 'r:ad:12');
  });
}

const context = FeedRecommendationContext(
  requestId: 'request-1',
  scene: 'home',
  position: 3,
  recallSource: 'itemcf',
  modelVersion: 'rank-v1',
  experimentId: 'exp-a',
);

PersistentBehaviorTracker _tracker(_RecordingQueue queue) {
  var eventSequence = 0;
  return PersistentBehaviorTracker(
    queue: queue,
    identityStore: ClientIdentityStore(
      generateId: (prefix) =>
          prefix == 'event' ? 'event-${++eventSequence}' : '$prefix-1',
    ),
    nowMilliseconds: () => 1720000000000,
  );
}

class _RecordingQueue implements BehaviorEventEnqueuer {
  final List<QueuedBehaviorEvent> events = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> enqueue(QueuedBehaviorEvent event) async => events.add(event);
}
