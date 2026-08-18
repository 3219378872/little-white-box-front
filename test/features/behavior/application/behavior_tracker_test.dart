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
