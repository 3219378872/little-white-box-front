import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/api.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';
import '../application/user_posts_notifier.dart';

class UserRepository implements UserPostsRepository {
  Future<GetUserResp> getUserProfile(int userId) {
    return apiCall<GetUserResp>(
      (ok, fail, eventually) => gw.getUser(
        userId,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> updateUserProfile(UpdateProfileReq req) {
    return apiCall<UpdateProfileResp>(
      (ok, fail, eventually) => gw.updateProfile(
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> followUser(int targetUserId) {
    return apiCall<FollowResp>(
      (ok, fail, eventually) => gw.follow(
        FollowReq(targetUserId: targetUserId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> unfollowUser(int targetUserId) {
    return apiCall<UnfollowResp>(
      (ok, fail, eventually) => gw.unfollow(
        UnfollowReq(targetUserId: targetUserId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<GetPostListResp> fetchUserPosts({
    required num userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${userId.toInt()}/posts'
        '?page=$page&pageSize=$pageSize&sortBy=$sortBy',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required num userId,
    required int page,
    required int pageSize,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${userId.toInt()}/favorites'
        '?page=$page&pageSize=$pageSize',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
