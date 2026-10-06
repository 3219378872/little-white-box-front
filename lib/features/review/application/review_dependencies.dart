import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/review_repository.dart';

/// 审核工作台仓储：权限、队列、任务快照与裁决都经由它访问网关。
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => const ReviewRepository(),
);
