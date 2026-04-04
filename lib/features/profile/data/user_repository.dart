import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

class UserRepository {
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
}
