import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_repository.dart';

void main() {
  test('classifies accepted, permanent, and retryable event results', () async {
    final client = _StubV2ApiClient({
      'results': [
        {'clientEventId': 'accepted', 'accepted': true, 'code': 0},
        {'clientEventId': 'invalid', 'accepted': false, 'code': 2},
        {'clientEventId': 'broker-down', 'accepted': false, 'code': 6},
      ],
    });
    final repository = BehaviorRepository(client: client);

    final result = await repository.send(
      BehaviorBatch(
        anonymousId: 'anonymous-1',
        sessionId: 'session-1',
        events: [event('accepted'), event('invalid'), event('broker-down')],
      ),
    );

    expect(result.acceptedEventIds, {'accepted'});
    expect(result.permanentlyRejectedEventIds, {'invalid'});
    expect(result.terminalEventIds, {'accepted', 'invalid'});
    expect(client.path, '/api/v2/behavior/events');
  });
}

ClientBehaviorEvent event(String id) => ClientBehaviorEvent(
  clientEventId: id,
  occurredAt: 1720000000000,
  action: 'click',
  targetId: 1,
  targetType: 'post',
  scene: 'home',
  requestId: 'request-1',
  recallSource: 'popular',
  modelVersion: 'rule-v1',
  experimentId: '',
);

class _StubV2ApiClient extends V2ApiClient {
  final Map<String, dynamic> response;
  String? path;

  _StubV2ApiClient(this.response);

  @override
  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    this.path = path;
    return response;
  }
}
