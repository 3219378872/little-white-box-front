import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/application/auth_notifier.dart';
import '../../post/data/post_repository.dart';
import '../data/assistant_repository.dart';

/// Assistant 会话、流式事件与记忆的数据源；测试在此注入假实现。
final assistantRepositoryProvider = Provider<AssistantDataSource>((ref) {
  return AssistantRepository();
});

/// 当前登录会话的身份键，用于隔离不同账号的 Assistant 线程与缓存。
final assistantUserKeyProvider = Provider<String>((ref) {
  return ref.watch(authenticatedSessionIdentityProvider) ?? '';
});

/// 附件图片选择器；测试替换以避免调起系统相册。
final assistantImagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

/// 附件图片上传复用帖子图片上传接口，拿到媒体标识后随消息发送。
final assistantAttachmentRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});
