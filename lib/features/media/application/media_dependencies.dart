import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/media_repository.dart';

/// 通用媒体上传仓储，供私信等需要上传图片/音视频的 feature 共用。
final mediaRepositoryProvider = Provider<MediaRepository>(
  (ref) => MediaRepository(),
);

/// 平台文件选择器封装；测试注入假实现以避免调起系统对话框。
final mediaPickerProvider = Provider<MediaPicker>((ref) => MediaPicker());
