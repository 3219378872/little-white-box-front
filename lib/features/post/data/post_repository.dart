import '../../../core/api/api_adapter.dart';
import '../../../core/api/image_mime.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 单张图片上传结果：`mediaId` 随帖子提交以关联媒体，`url` 写入帖子图片列表。
class UploadedImage {
  final Object mediaId;
  final String url;
  final String thumbnailUrl;

  const UploadedImage({
    required this.mediaId,
    required this.url,
    this.thumbnailUrl = '',
  });
}

/// 帖子读写的 Gateway 封装：详情走 v1，发帖/编辑/删除走 v2 生成 SDK，图片走 multipart 上传。
///
/// SDK 回调失败统一经 [apiCall] 转为 `ApiException`。
class PostRepository {
  /// 读取帖子详情（`GET /api/v1/post/{id}`），含当前账号的点赞/收藏态。
  Future<GetPostResp> getPostDetail(Object postId) {
    return apiCall<GetPostResp>(
      (ok, fail, eventually) =>
          gw.getPost(postId, ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 新建帖子（`POST /api/v2/post`）；幂等键由调用方放在请求体里。
  Future<CreatePostResp> createNewPost(CreatePostReq req) {
    return apiCall<CreatePostResp>(
      (ok, fail, eventually) =>
          gw.createPostV2(req, ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 编辑帖子（`PUT /api/v2/post/{id}`）；请求体带 `expectedRevision` 做乐观并发控制。
  Future<UpdatePostResp> updateExistingPost(
    Object postId,
    UpdatePostV2Req req,
  ) {
    return apiCall<UpdatePostResp>(
      (ok, fail, eventually) => gw.updatePostV2(
        postId,
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 删除帖子（`DELETE /api/v2/post/{id}`），同样以 [expectedRevision] 防止误删已被修改的版本。
  Future<void> deleteExistingPost(
    Object postId, {
    required int expectedRevision,
  }) {
    return apiCall<DeletePostResp>(
      (ok, fail, eventually) => gw.deletePostV2(
        postId,
        DeletePostV2Req(postId: postId, expectedRevision: expectedRevision),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 以 multipart 协议上传单张图片，返回媒体标识和 URL。
  Future<UploadedImage> uploadImageMultipart({
    required List<int> bytes,
    required String filename,
  }) {
    // 上传到 `/api/v1/media/image`；响应缺少 url 视为格式错误。
    return apiPostMultipart<UploadedImage>(
      path: '/api/v1/media/image',
      fieldName: 'file',
      filename: filename,
      bytes: bytes,
      contentType: inferImageMime(filename, bytes),
      decodeData: (data) {
        final url = data['url'] as String? ?? '';
        if (url.isEmpty) {
          throw const FormatException('upload response missing url');
        }
        return UploadedImage(
          mediaId: data['mediaId'] ?? 0,
          url: url,
          thumbnailUrl: data['thumbnailUrl'] as String? ?? '',
        );
      },
    );
  }
}
