import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../media/data/media_repository.dart';

/// Owns one selection through upload retries and message retries.
/// A completed upload is retained until its message succeeds or the task is cancelled.
class MediaSendController extends ChangeNotifier {
  MediaSendController(this.repository);
  final MediaRepository repository;
  bool busy = false;
  String? error;
  String? filename;
  XFile? _file;
  MediaKind? _kind;
  String? _uploadKey;
  UploadedMedia? _uploaded;
  Future<bool> Function(UploadedMedia, MediaKind)? _send;
  bool Function()? _isCurrent;
  bool _disposed = false;
  int _generation = 0;
  bool get hasPending => _file != null;

  Future<void> start(
    XFile file,
    MediaKind kind, {
    required Future<bool> Function(UploadedMedia, MediaKind) send,
    required bool Function() isCurrent,
  }) async {
    if (busy || _disposed || !isCurrent()) return;
    _generation++;
    _file = file;
    _kind = kind;
    filename = file.name;
    // 上传键沿用十进制时间戳，与既有格式保持一致。
    _uploadKey = newPrefixedRequestId('upload', timestampRadix: 10);
    _uploaded = null;
    _send = send;
    _isCurrent = isCurrent;
    await retry();
  }

  Future<void> retry() async {
    if (busy || _file == null || _disposed) return;
    final generation = _generation;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        (_isCurrent?.call() ?? false);
    if (!current()) {
      cancel();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      var uploaded = _uploaded;
      if (uploaded == null) {
        final result = await repository.upload(
          _file!,
          _kind!,
          _uploadKey!,
          isCurrent: current,
        );
        if (!current()) return;
        _uploaded = uploaded = result;
      }
      if (!current()) return;
      if (await _send!(uploaded, _kind!)) {
        if (current()) {
          _file = null;
          filename = null;
          _uploaded = null;
        }
      } else if (current()) {
        error = '媒体已上传，消息发送失败，请重试';
      }
    } catch (e) {
      if (current()) error = friendlyErrorMessage(e);
    } finally {
      if (!_disposed && generation == _generation) {
        if (!current()) {
          _file = null;
          filename = null;
          _uploaded = null;
          error = null;
        }
        busy = false;
        notifyListeners();
      }
    }
  }

  void cancel() {
    _generation++;
    _file = null;
    _uploaded = null;
    _kind = null;
    _uploadKey = null;
    _send = null;
    _isCurrent = null;
    filename = null;
    error = null;
    busy = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
