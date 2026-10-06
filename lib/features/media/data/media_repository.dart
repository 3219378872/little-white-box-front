import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/gateway.dart' as gateway;

/// 可上传的媒体类型：[path] 是上传接口路径段与响应中的 `fileType`，[messageType] 是
/// 私信 `msgType` 取值，[maxBytes] 是客户端预检的大小上限。
enum MediaKind {
  image('image', 2, 10 * 1024 * 1024),
  video('video', 3, 100 * 1024 * 1024),
  audio('audio', 4, 10 * 1024 * 1024);

  const MediaKind(this.path, this.messageType, this.maxBytes);
  final String path;
  final int messageType;
  final int maxBytes;
}

/// 上传成功后的媒体 ID 与可访问地址。
class UploadedMedia {
  const UploadedMedia({required this.mediaId, required this.url});
  final Object mediaId;
  final String url;
}

/// 媒体上传仓储：以 multipart 流式上传到网关 `/api/v1/media/{image,video,audio}`。
class MediaRepository {
  /// 上传 [file]；[key] 作为幂等键随表单提交，重试同一文件时复用以避免重复创建媒体。
  /// [isCurrent] 返回 false 时放弃上传结果（如用户已离开会话）。
  Future<UploadedMedia> upload(
    XFile file,
    MediaKind kind,
    String key, {
    required bool Function() isCurrent,
  }) async {
    // 先在本地拦截空文件与超限文件，省去一次注定失败的上传。
    final length = await file.length();
    if (length <= 0 || length > kind.maxBytes) {
      throw ApiException('文件须为 1 字节至 ${kind.maxBytes ~/ (1024 * 1024)} MiB');
    }
    return apiPostMultipart<UploadedMedia>(
      path: switch (kind) {
        MediaKind.image => gateway.uploadImagePath,
        MediaKind.video => gateway.uploadVideoPath,
        MediaKind.audio => gateway.uploadAudioPath,
      },
      fieldName: 'file',
      filename: file.name,
      openRead: file.openRead,
      length: length,
      fields: {'idempotencyKey': key},
      isCurrent: isCurrent,
      timeout: const Duration(seconds: 330),
      // 响应必须带正整数 mediaId 与 http(s) 地址；音视频还要核对服务端识别的类型。
      decodeData: (data) {
        final id = data['mediaId'];
        final url = data['url'] as String? ?? '';
        final uri = Uri.tryParse(url);
        if (!jsonInt64IsPositive(id) ||
            uri == null ||
            !['http', 'https'].contains(uri.scheme) ||
            uri.host.isEmpty ||
            (kind != MediaKind.image && data['fileType'] != kind.path)) {
          throw const FormatException('上传响应缺少有效媒体标识或地址');
        }
        return UploadedMedia(mediaId: id!, url: url);
      },
    );
  }
}

/// 按媒体类型调起系统选择器：图片与视频从相册选取，音频通过文件对话框限定格式。
class MediaPicker {
  /// 用户取消时返回 null。
  Future<XFile?> pick(MediaKind kind) {
    switch (kind) {
      case MediaKind.image:
        return ImagePicker().pickImage(source: ImageSource.gallery);
      case MediaKind.video:
        return ImagePicker().pickVideo(source: ImageSource.gallery);
      case MediaKind.audio:
        return openFile(
          acceptedTypeGroups: const [
            XTypeGroup(
              label: '音频 MP3 / WAV / M4A',
              extensions: ['mp3', 'wav', 'm4a'],
              mimeTypes: [
                'audio/mpeg',
                'audio/wav',
                'audio/x-wav',
                'audio/mp4',
                'audio/x-m4a',
              ],
              uniformTypeIdentifiers: [
                'public.mp3',
                'com.microsoft.waveform-audio',
                'com.apple.m4a-audio',
              ],
            ),
          ],
        );
    }
  }
}
