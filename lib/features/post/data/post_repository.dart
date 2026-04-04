import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

class PostRepository {
  Future<GetPostResp> getPostDetail(int postId) {
    return apiCall<GetPostResp>(
      (ok, fail, eventually) => gw.getPost(
        postId,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<CreatePostResp> createNewPost(CreatePostReq req) {
    return apiCall<CreatePostResp>(
      (ok, fail, eventually) => gw.createPost(
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> updateExistingPost(int postId, UpdatePostReq req) {
    return apiCall<UpdatePostResp>(
      (ok, fail, eventually) => gw.updatePost(
        postId,
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> deleteExistingPost(int postId) {
    return apiCall<DeletePostResp>(
      (ok, fail, eventually) => gw.deletePost(
        postId,
        DeletePostReq(postId: postId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
