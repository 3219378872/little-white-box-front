import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 点赞与收藏写接口仓储：点赞走 `/api/v1/like`（POST 点赞、DELETE 取消），
/// 收藏走 `/api/v1/favorite`（同上），失败统一转为 `ApiException`。
class InteractionRepository {
  /// 点赞目标；[targetType] 1 为帖子。
  Future<void> likeTarget(Object targetId, int targetType) {
    return apiCall<LikeResp>(
      (ok, fail, eventually) => gw.like(
        LikeReq(targetId: targetId, targetType: targetType),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 取消点赞。
  Future<void> unlikeTarget(Object targetId, int targetType) {
    return apiCall<UnlikeResp>(
      (ok, fail, eventually) => gw.unlike(
        UnlikeReq(targetId: targetId, targetType: targetType),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 收藏帖子。
  Future<void> favoritePost(Object postId) {
    return apiCall<FavoriteResp>(
      (ok, fail, eventually) => gw.favorite(
        FavoriteReq(postId: postId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 取消收藏。
  Future<void> unfavoritePost(Object postId) {
    return apiCall<UnfavoriteResp>(
      (ok, fail, eventually) => gw.unfavorite(
        UnfavoriteReq(postId: postId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
