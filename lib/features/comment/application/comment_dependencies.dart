import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/comment_repository.dart';

/// 评论读取与发表仓储，评论 notifier 的唯一网络入口。
final commentRepositoryProvider = Provider<CommentRepository>((ref) {
  return CommentRepository();
});
