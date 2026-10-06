import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/api.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 用户帖子/收藏分页读取接口；分页 notifier 只依赖它，测试可替换分页行为。
abstract class UserPostsRepository {
  /// 读取用户发布的帖子，按游标分页；空游标表示第一页。
  Future<GetPostListResp> fetchUserPosts({
    required Object userId,
    required String cursor,
    required int pageSize,
    int sortBy = 1,
  });

  /// 读取用户收藏的帖子，按游标分页；空游标表示第一页。
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required String cursor,
    required int pageSize,
  });
}

/// 用户资料、关注与个人页列表的 Gateway 封装；失败经 [apiCall] 转为 `ApiException`。
class UserRepository implements UserPostsRepository {
  /// 读取用户资料（`GET /api/v1/user/{id}`），含当前账号对其的关注态。
  Future<GetUserResp> getUserProfile(Object userId) {
    return apiCall<GetUserResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/user/${jsonInt64Id(userId)}',
        ok: (data) {
          // 关注态是关注按钮的依据，缺失时宁可报格式错误也不默认成「未关注」。
          if (data['isFollowing'] is! bool) {
            throw const ApiException('用户关注状态响应格式无效');
          }
          ok(GetUserResp.fromJson(data));
        },
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 更新当前用户的昵称、头像与简介（`PUT /api/v1/user/profile`）。
  Future<void> updateUserProfile(UpdateProfileReq req) {
    return apiCall<UpdateProfileResp>(
      (ok, fail, eventually) =>
          gw.updateProfile(req, ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 关注用户（`POST /api/v1/user/follow`）。
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

  /// 取消关注（`DELETE /api/v1/user/follow`）。
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
    required String cursor,
    required int pageSize,
    int sortBy = 1,
  }) {
    // 手写 GET 以拼接分页与排序 query；游标需 URL 编码。
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${jsonInt64Id(userId)}/posts'
        '?pageSize=$pageSize&sortBy=$sortBy&cursor=${Uri.encodeQueryComponent(cursor)}',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  @override
  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required String cursor,
    required int pageSize,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/users/${jsonInt64Id(userId)}/favorites'
        '?pageSize=$pageSize&cursor=${Uri.encodeQueryComponent(cursor)}',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
