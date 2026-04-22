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

  /// 以 multipart 协议上传单张图片，返回图片 URL。
  Future<String> uploadImageMultipart({
    required List<int> bytes,
    required String filename,
  }) {
    return apiPostMultipart<String>(
      path: '/api/v1/media/image',
      fieldName: 'file',
      filename: filename,
      bytes: bytes,
      contentType: _inferImageMime(filename, bytes),
      decodeData: (data) => data['url'] as String,
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
  // 扩展名缺失时回退到 magic bytes 识别
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
