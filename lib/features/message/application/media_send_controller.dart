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
  // 对页面公开的进度、错误与文件名，变化时 notifyListeners。
  bool busy = false;
  String? error;
  String? filename;
  // 当前待发送的选择、上传幂等键与已上传结果。
  XFile? _file;
  MediaKind? _kind;
  String? _uploadKey;
  UploadedMedia? _uploaded;
  // 由页面注入的「把已上传媒体作为消息发出」回调，返回是否发送成功。
  Future<bool> Function(UploadedMedia, MediaKind)? _send;
  // 页面提供的「仍然有效」判断：页面、会话或登录身份变化后返回 false。
  bool Function()? _isCurrent;
  bool _disposed = false;
  // 任务代次：开始新任务、取消或释放时递增，使旧任务的异步结果失效。
  int _generation = 0;

  /// 是否有尚未发送成功的媒体（上传中、上传失败或发送失败）。
  bool get hasPending => _file != null;

  /// 开始一个新的媒体发送任务：记录选择、生成上传键，然后立即执行一次上传+发送。
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

  /// 执行或重试当前任务：已上传成功时跳过上传直接发送消息。
  Future<void> retry() async {
    if (busy || _file == null || _disposed) return;
    final generation = _generation;
    bool current() =>
        !_disposed &&
        generation == _generation &&
        (_isCurrent?.call() ?? false);
    // 页面已不再有效：直接放弃任务。
    if (!current()) {
      cancel();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      // 上传：同一任务的重试复用上传键，成功结果缓存到消息发送成功为止。
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
      // 发送消息：成功后清除任务；失败保留已上传结果，下次重试只重发消息。
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
      // 本任务仍是最新一代：失效时清空任务，并结束忙碌态。
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

  /// 取消当前任务并丢弃已上传结果，使在途的上传/发送结果失效。
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
