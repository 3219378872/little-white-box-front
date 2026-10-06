import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/interaction_repository.dart';

/// 点赞/收藏写操作仓储；帖子卡片与详情页的交互 notifier 都经由它发请求。
final interactionRepositoryProvider = Provider<InteractionRepository>((ref) {
  return InteractionRepository();
});
