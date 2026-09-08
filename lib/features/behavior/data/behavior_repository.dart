import '../../../core/api/api_exceptions.dart';
import '../../../core/api/v2_api_client.dart';
import 'behavior_event.dart';
import 'behavior_identity.dart';

abstract interface class BehaviorEventTransport {
  Future<BehaviorSendResult> send(BehaviorBatch batch);
}

class BehaviorRepository implements BehaviorEventTransport {
  final V2ApiClient _client;

  const BehaviorRepository({V2ApiClient client = const V2ApiClient()})
    : _client = client;

  @override
  Future<BehaviorSendResult> send(BehaviorBatch batch) async {
    final identity = await loadBehaviorIdentity();
    if (batch.ownerIdentity == null ||
        batch.ownerIdentity != identity.ownerIdentity) {
      throw const ApiException('行为事件所属会话已变化');
    }
    final response = await _client.post('/api/v2/behavior/events', {
      'anonymousId': batch.anonymousId,
      'sessionId': batch.sessionId,
      'events': batch.events.map((event) => event.toJson()).toList(),
    }, expectedSessionRevision: identity.sessionRevision);
    final results = response['results'] as List<dynamic>? ?? const [];
    final accepted = <String>{};
    final permanentlyRejected = <String>{};
    for (final raw in results) {
      if (raw is! Map) continue;
      final eventId = raw['clientEventId']?.toString() ?? '';
      if (eventId.isEmpty) continue;
      if (raw['accepted'] == true) {
        accepted.add(eventId);
      } else if ((raw['code'] as num?)?.toInt() == 2) {
        // BehaviorService uses ParamError for events that can never succeed
        // unchanged, including malformed and expired client events.
        permanentlyRejected.add(eventId);
      }
    }
    return BehaviorSendResult(accepted, permanentlyRejected);
  }
}
