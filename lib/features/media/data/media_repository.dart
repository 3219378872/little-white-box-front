import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';

enum MediaKind {
  image('image', 2, 10 * 1024 * 1024),
  video('video', 3, 100 * 1024 * 1024),
  audio('audio', 4, 10 * 1024 * 1024);

  const MediaKind(this.path, this.messageType, this.maxBytes);
  final String path;
  final int messageType;
  final int maxBytes;
}

class UploadedMedia {
  const UploadedMedia({required this.mediaId, required this.url});
  final Object mediaId;
  final String url;
}

class MediaRepository {
  Future<UploadedMedia> upload(
    XFile file,
    MediaKind kind,
    String key, {
    required bool Function() isCurrent,
  }) async {
    final length = await file.length();
    if (length <= 0 || length > kind.maxBytes) {
      throw ApiException('文件须为 1 字节至 ${kind.maxBytes ~/ (1024 * 1024)} MiB');
    }
    return apiPostMultipart<UploadedMedia>(
      path: '/api/v1/media/${kind.path}',
      fieldName: 'file',
      filename: file.name,
      openRead: file.openRead,
      length: length,
      fields: {'idempotencyKey': key},
      isCurrent: isCurrent,
      timeout: const Duration(seconds: 330),
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

class MediaPicker {
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

final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(),
);
final mediaPickerProvider = Provider<MediaPicker>((ref) => MediaPicker());
