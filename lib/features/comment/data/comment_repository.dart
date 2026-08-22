import '../../../core/api/api_adapter.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/api.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

class CommentRepository {
  /// 绕过 SDK 的 getCommentList()，直接调用 apiGet 拼接 query 参数
  Future<GetCommentListResp> fetchComments({
    required Object postId,
    required int page,
    required int pageSize,
    required int sortBy,
  }) {
    return apiCall<GetCommentListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/comments/${jsonInt64Id(postId)}?page=$page&pageSize=$pageSize&sortBy=$sortBy',
        ok: (data) => ok(GetCommentListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 楼中楼全量分页（时间正序）；同样绕过 SDK 拼 query 参数
  Future<GetCommentRepliesResp> fetchReplies({
    required Object commentId,
    required int page,
    required int pageSize,
  }) {
    return apiCall<GetCommentRepliesResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/comments/${jsonInt64Id(commentId)}/replies?page=$page&pageSize=$pageSize',
        ok: (data) => ok(GetCommentRepliesResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<CreateCommentResp> createNewComment(CreateCommentReq req) {
    return apiCall<CreateCommentResp>(
      (ok, fail, eventually) => gw.createComment(
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<void> deleteExistingComment(Object commentId) {
    return apiCall<DeleteCommentResp>(
      (ok, fail, eventually) => gw.deleteComment(
        commentId,
        DeleteCommentReq(commentId: commentId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
