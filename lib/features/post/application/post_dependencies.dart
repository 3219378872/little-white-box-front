import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/post_repository.dart';

/// 帖子详情、发帖/编辑与图片上传仓储，详情页与编辑器共用。
final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});
