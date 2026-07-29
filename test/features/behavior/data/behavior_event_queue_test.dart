import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event_queue.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists, deduplicates, and caps the local queue', () async {
    final connectivity = _FakeConnectivity(true);
    final first = BehaviorEventQueue(
      transport: _FakeTransport(),
      connectivity: connectivity,
      maxQueueSize: 3,
      autoFlush: false,
    );
    addTearDown(first.dispose);

    await first.enqueue(queued('event-1'));
    await first.enqueue(queued('event-2'));
    await first.enqueue(queued('event-2'));
    await first.enqueue(queued('event-3'));
    await first.enqueue(queued('event-4'));

    expect(first.pendingEvents.map((item) => item.event.clientEventId), [
      'event-2',
      'event-3',
      'event-4',
    ]);

    final restored = BehaviorEventQueue(
      transport: _FakeTransport(),
      connectivity: connectivity,
      maxQueueSize: 3,
      autoFlush: false,
    );
    addTearDown(restored.dispose);
    await restored.initialize();

    expect(restored.pendingEvents.map((item) => item.event.clientEventId), [
      'event-2',
      'event-3',
      'event-4',
    ]);
  });

  test('honors batch size and removes only accepted event ids', () async {
    final transport = _FakeTransport(
      responses: [
        const BehaviorSendResult({'event-1'}),
        const BehaviorSendResult({'event-2', 'event-3'}),
      ],
    );
    final queue = BehaviorEventQueue(
      transport: transport,
      connectivity: _FakeConnectivity(true),
      maxBatchSize: 2,
      autoFlush: false,
    );
    addTearDown(queue.dispose);
    await queue.enqueue(queued('event-1'));
    await queue.enqueue(queued('event-2'));
    await queue.enqueue(queued('event-3'));

    await queue.flush();

    expect(transport.batches.single.events, hasLength(2));
    expect(queue.pendingEvents.map((item) => item.event.clientEventId), [
      'event-2',
      'event-3',
    ]);

    await queue.flush();
    expect(queue.pendingCount, 0);
  });

  test('drops permanent rejects and retries transient rejects', () async {
    final transport = _FakeTransport(
      responses: [
        const BehaviorSendResult({'event-1'}, {'event-invalid'}),
        const BehaviorSendResult({'event-temporary'}),
      ],
    );
    final queue = BehaviorEventQueue(
      transport: transport,
      connectivity: _FakeConnectivity(true),
      maxBatchSize: 3,
      autoFlush: false,
    );
    addTearDown(queue.dispose);
    await queue.enqueue(queued('event-1'));
    await queue.enqueue(queued('event-invalid'));
    await queue.enqueue(queued('event-temporary'));

    await queue.flush();

    expect(queue.pendingEvents.map((item) => item.event.clientEventId), [
      'event-temporary',
    ]);

    await queue.flush();
    expect(queue.pendingCount, 0);
    expect(transport.batches.last.events.map((event) => event.clientEventId), [
      'event-temporary',
    ]);
  });

  test('flushes retained events when connectivity returns', () async {
    final connectivity = _FakeConnectivity(false);
    final transport = _FakeTransport();
    final queue = BehaviorEventQueue(
      transport: transport,
      connectivity: connectivity,
      flushDelay: const Duration(hours: 1),
    );
    addTearDown(queue.dispose);
    await queue.enqueue(queued('event-offline'));

    await queue.flush();
    expect(transport.batches, isEmpty);

    connectivity.setOnline(true);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(transport.batches, hasLength(1));
    expect(queue.pendingCount, 0);
  });

  test('retries a failed batch with the same client event id', () async {
    final transport = _FakeTransport(failuresBeforeSuccess: 1);
    final queue = BehaviorEventQueue(
      transport: transport,
      connectivity: _FakeConnectivity(true),
      flushDelay: Duration.zero,
      baseRetryDelay: const Duration(milliseconds: 1),
      maxRetryDelay: const Duration(milliseconds: 2),
    );
    addTearDown(queue.dispose);

    await queue.enqueue(queued('event-retry'));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(transport.batches, hasLength(2));
    expect(
      transport.batches
          .map((batch) => batch.events.single.clientEventId)
          .toSet(),
      {'event-retry'},
    );
    expect(queue.pendingCount, 0);
  });
}

QueuedBehaviorEvent queued(String id) => QueuedBehaviorEvent(
  anonymousId: 'anonymous-1',
  sessionId: 'session-1',
  event: ClientBehaviorEvent(
    clientEventId: id,
    occurredAt: 1720000000000,
    action: 'click',
    targetId: 1,
    targetType: 'post',
    scene: 'home',
    requestId: 'request-1',
    position: 1,
    recallSource: 'popular',
    modelVersion: 'rule-v1',
    experimentId: '',
  ),
);

class _FakeConnectivity implements ConnectivityMonitor {
  final StreamController<bool> _controller = StreamController.broadcast();
  bool online;

  _FakeConnectivity(this.online);

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get onStatusChanged => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }
}

class _FakeTransport implements BehaviorEventTransport {
  final List<BehaviorSendResult> responses;
  final List<BehaviorBatch> batches = [];
  int failuresBeforeSuccess;

  _FakeTransport({this.responses = const [], this.failuresBeforeSuccess = 0});

  @override
  Future<BehaviorSendResult> send(BehaviorBatch batch) async {
    batches.add(batch);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw Exception('offline');
    }
    if (responses.isNotEmpty) return responses.removeAt(0);
    return BehaviorSendResult(
      batch.events.map((event) => event.clientEventId).toSet(),
    );
  }
}
