import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/api.dart';
import '../../../sdk/data/gateway.dart';

class PostListRepository {
  /// 绕过 SDK 的 getPostList()，直接调用 apiGet 拼接 query 参数
  Future<GetPostListResp> fetchPosts({
    required String cursor,
    required int pageSize,
    required int sortBy,
  }) {
    return apiCall<GetPostListResp>(
      (ok, fail, eventually) => apiGet(
        '/api/v1/posts?pageSize=$pageSize&sortBy=$sortBy&cursor=${Uri.encodeQueryComponent(cursor)}',
        ok: (data) => ok(GetPostListResp.fromJson(data)),
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
