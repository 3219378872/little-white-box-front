import '../../../core/api/json_int64.dart';
import '../../../core/auth/jwt_decoder.dart';
import '../../../sdk/vars/kv.dart';

/// 行为事件的归属：[ownerIdentity] 为 `user:<id>` 或 `anonymous:<会话版本>`，
/// 令牌存在却解不出用户时为 null（不上报）；[sessionRevision] 用于发送时绑定会话版本。
class BehaviorIdentity {
  final String? ownerIdentity;
  final int sessionRevision;

  const BehaviorIdentity({this.ownerIdentity, required this.sessionRevision});
}

/// 从本地令牌存储读取当前会话的行为归属；匿名身份带会话版本，登录或登出后，
/// 先前匿名时段的事件不会以新身份发送。
Future<BehaviorIdentity> loadBehaviorIdentity() async {
  final context = await getTokenSessionContext();
  final snapshot = context.snapshot;
  if (snapshot == null) {
    return BehaviorIdentity(
      ownerIdentity: 'anonymous:${context.revision}',
      sessionRevision: context.revision,
    );
  }
  final userId = extractUserIdFromToken(snapshot.tokens.accessToken);
  return BehaviorIdentity(
    ownerIdentity: jsonInt64IsPositive(userId)
        ? 'user:${jsonInt64Id(userId)}'
        : null,
    sessionRevision: context.revision,
  );
}
