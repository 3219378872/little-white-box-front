import '../../../core/api/api_adapter.dart';
import '../../../core/api/image_mime.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

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

class PostRepository {
  Future<GetPostResp> getPostDetail(Object postId) {
    return apiCall<GetPostResp>(
      (ok, fail, eventually) =>
          gw.getPost(postId, ok: ok, fail: fail, eventually: eventually),
    );
  }

  Future<CreatePostResp> createNewPost(CreatePostReq req) {
    return apiCall<CreatePostResp>(
      (ok, fail, eventually) =>
          gw.createPostV2(req, ok: ok, fail: fail, eventually: eventually),
    );
  }

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
