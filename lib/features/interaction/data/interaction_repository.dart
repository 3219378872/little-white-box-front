import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

class InteractionRepository {
  Future<void> likeTarget(int targetId, int targetType) {
    return apiCall<LikeResp>(
      (ok, fail, eventually) => gw.like(
        LikeReq(targetId: targetId, targetType: targetType),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> unlikeTarget(int targetId, int targetType) {
    return apiCall<UnlikeResp>(
      (ok, fail, eventually) => gw.unlike(
        UnlikeReq(targetId: targetId, targetType: targetType),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> favoritePost(int postId) {
    return apiCall<FavoriteResp>(
      (ok, fail, eventually) => gw.favorite(
        FavoriteReq(postId: postId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> unfavoritePost(int postId) {
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
