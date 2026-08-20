import '../../../core/api/api_adapter.dart';
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

  Future<UpdatePostResp> updateExistingPost(Object postId, UpdatePostV2Req req) {
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

  Future<void> deleteExistingPost(Object postId, {required int expectedRevision}) {
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
      contentType: _inferImageMime(filename, bytes),
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

/// 根据文件扩展名 / magic bytes 推断图片 MIME。
/// 后端白名单：image/jpeg、image/png、image/webp
String _inferImageMime(String filename, List<int> bytes) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return 'image/webp';
  }
  return 'image/jpeg';
}
