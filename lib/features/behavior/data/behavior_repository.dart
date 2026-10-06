import '../../../core/api/api_exceptions.dart';
import '../../../core/api/v2_api_client.dart';
import 'behavior_event.dart';
import 'behavior_identity.dart';

/// 行为批次的发送抽象，供 [BehaviorEventQueue] 依赖与测试替换。
abstract interface class BehaviorEventTransport {
  /// 发送一个批次并返回逐条结果；整批失败时抛错，由队列整体重试。
  Future<BehaviorSendResult> send(BehaviorBatch batch);
}

/// 经网关 `POST /api/v2/behavior/events` 批量上报行为事件，并把逐条结果归类为
/// 已受理与永久拒绝；其余（如临时失败）留在队列中等待重试。
class BehaviorRepository implements BehaviorEventTransport {
  final V2ApiClient _client;

  const BehaviorRepository({V2ApiClient client = const V2ApiClient()})
    : _client = client;

  @override
  Future<BehaviorSendResult> send(BehaviorBatch batch) async {
    // 批次归属必须与当前会话一致，并把请求绑定到该会话版本，防止以其他账号身份上报。
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
