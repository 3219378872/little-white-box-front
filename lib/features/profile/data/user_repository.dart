import '../../../core/api/api_adapter.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/api.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';
import '../application/user_posts_notifier.dart';

class UserRepository implements UserPostsRepository {
  Future<GetUserResp> getUserProfile(Object userId) {
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

  Future<void> followUser(Object targetUserId) {
    return apiCall<FollowResp>(
      (ok, fail, eventually) => gw.follow(
        FollowReq(targetUserId: targetUserId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> unfollowUser(Object targetUserId) {
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
    required Object userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${jsonInt64Id(userId)}/posts'
        '?page=$page&pageSize=$pageSize&sortBy=$sortBy',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required int page,
    required int pageSize,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${jsonInt64Id(userId)}/favorites'
        '?page=$page&pageSize=$pageSize',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
