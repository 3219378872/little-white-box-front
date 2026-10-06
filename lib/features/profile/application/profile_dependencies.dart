import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/personalization_repository.dart';
import '../data/user_repository.dart';

/// 用户资料、关注与资料编辑的仓储，个人页、编辑页与帖子详情共用。
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// 个性化推荐开关的仓储，仅本人主页读写。
final personalizationRepositoryProvider = Provider<PersonalizationRepository>((
  ref,
) {
  return PersonalizationRepository();
});

/// 用户帖子/收藏分页数据源；以接口暴露便于测试替换分页行为。
final userPostsRepositoryProvider = Provider<UserPostsRepository>((ref) {
  return UserRepository();
});
