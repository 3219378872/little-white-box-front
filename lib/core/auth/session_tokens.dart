import '../../sdk/data/tokens.dart';
import 'jwt_decoder.dart';

/// 由一对原始令牌构建持久化会话。
///
/// 过期时间从各自 JWT 的 `exp` 声明解出（不验签）；缺失时记 0，
/// 表示"未知"，刷新决策只依赖 refreshToken 是否存在，不依赖这些值。
Tokens buildStoredTokens({
  required String accessToken,
  required String refreshToken,
}) {
  return Tokens(
    accessToken: accessToken,
    accessExpire: extractExpiryFromToken(accessToken),
    refreshToken: refreshToken,
    refreshExpire: extractExpiryFromToken(refreshToken),
    refreshAfter: 0,
  );
}
