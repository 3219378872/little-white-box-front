import '../../../core/api/json_int64.dart';
import '../../../core/auth/jwt_decoder.dart';
import '../../../sdk/vars/kv.dart';

class BehaviorIdentity {
  final String? ownerIdentity;
  final int sessionRevision;

  const BehaviorIdentity({this.ownerIdentity, required this.sessionRevision});
}

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
