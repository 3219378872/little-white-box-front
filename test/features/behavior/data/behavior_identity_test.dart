import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/features/behavior/application/behavior_tracker.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event_queue.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_repository.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

String _jwt(int id) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'userId': id})))}.sig';
Future<void> _login(int id) async {
  await setTokens(buildStoredTokens(accessToken: _jwt(id), refreshToken: ''));
}

class _Online implements ConnectivityMonitor {
  @override
  Future<bool> get isOnline async => true;
  @override
  Stream<bool> get onStatusChanged => const Stream.empty();
}

BehaviorEventQueue _queue() => BehaviorEventQueue(
  transport: const BehaviorRepository(),
  connectivity: _Online(),
  autoFlush: false,
);

QueuedBehaviorEvent _event(String id, String? owner) => QueuedBehaviorEvent(
  ownerIdentity: owner,
  anonymousId: 'device',
  sessionId: 'browser-session',
  event: ClientBehaviorEvent(
    clientEventId: id,
    occurredAt: DateTime.now().millisecondsSinceEpoch,
    action: 'click',
    targetId: 1,
    targetType: 'post',
    scene: 'home',
    requestId: 'request-$id',
    position: 1,
    recallSource: 'popular',
    modelVersion: 'model',
    experimentId: '',
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('restart and account switch retain A events while allowing B events to flush', () async {
    final first = _queue();
    await _login(1);
    await first.enqueue(_event('a', 'user:1'));
    first.dispose();
    await _login(2);
    final restored = _queue();
    addTearDown(restored.dispose);
    await restored.initialize();
    await restored.enqueue(_event('b', 'user:2'));
    final sent = <http.Request>[];
    setApiClient(
      MockClient((request) async {
        sent.add(request);
        final events = jsonDecode(request.body)['events'] as List;
        return http.Response(
          jsonEncode({
            'results': [
              for (final event in events)
                {'clientEventId': event['clientEventId'], 'accepted': true},
            ],
          }),
          200,
        );
      }),
    );
    await restored.flush();
    expect(sent.single.headers['Authorization'], 'Bearer ${_jwt(2)}');
    expect(jsonDecode(sent.single.body)['events'][0]['clientEventId'], 'b');
    expect(restored.pendingEvents.single.event.clientEventId, 'a');
    await _login(1);
    await restored.flush();
    expect(sent.last.headers['Authorization'], 'Bearer ${_jwt(1)}');
    expect(jsonDecode(sent.last.body)['events'][0]['clientEventId'], 'a');
    expect(restored.pendingCount, 0);
  });

  test(
    'legacy events with unknown owners remain quarantined across restart',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final legacy = _event('legacy', null).toJson();
      await preferences.setString(
        'behavior.event_queue.v1',
        jsonEncode([legacy]),
      );
      await _login(2);
      var requests = 0;
      setApiClient(
        MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        }),
      );
      final queue = _queue();
      await queue.flush();
      expect(requests, 0);
      expect(queue.unattributedCount, 1);
      expect(jsonDecode(preferences.getString('behavior.event_queue.v1')!), [
        legacy,
      ]);
      queue.dispose();
      final restored = _queue();
      addTearDown(restored.dispose);
      await restored.flush();
      expect(restored.unattributedCount, 1);
      expect(requests, 0);
    },
  );

  test(
    'anonymous backlog is not sent with a subsequently authenticated token',
    () async {
      final queue = _queue();
      addTearDown(queue.dispose);
      await queue.enqueue(_event('anonymous', 'anonymous:0'));
      await _login(2);
      var sent = false;
      setApiClient(
        MockClient((_) async {
          sent = true;
          return http.Response('{}', 200);
        }),
      );
      await queue.flush();
      expect(sent, isFalse);
      expect(queue.pendingCount, 1);
    },
  );

  test(
    'tracker captures the owner before asynchronous queue initialization',
    () async {
      await _login(1);
      final gate = Completer<void>();
      final recording = _DelayedQueue(gate.future);
      final tracker = PersistentBehaviorTracker(
        queue: recording,
        identityStore: ClientIdentityStore(),
      );
      final tracking = tracker.trackClick(
        1,
        const FeedRecommendationContext(
          requestId: 'request-a',
          scene: 'home',
          position: 1,
          recallSource: 'popular',
          modelVersion: '',
          experimentId: '',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await _login(2);
      gate.complete();
      await tracking;
      expect(recording.events.single.ownerIdentity, 'user:1');
    },
  );
}

class _DelayedQueue implements BehaviorEventEnqueuer {
  final Future<void> gate;
  final events = <QueuedBehaviorEvent>[];
  _DelayedQueue(this.gate);
  @override
  Future<void> initialize() => gate;
  @override
  Future<void> enqueue(QueuedBehaviorEvent event) async => events.add(event);
}
