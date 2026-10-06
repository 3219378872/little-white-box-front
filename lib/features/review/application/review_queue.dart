import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../sdk/data/gateway.dart';
import '../data/review_repository.dart';
import 'review_dependencies.dart';
import 'reviewer_access.dart';

/// 工作台首页的各队列待处理数量。
final reviewQueueProvider = FutureProvider.autoDispose<ReviewQueueResp>((ref) {
  return ref.read(reviewRepositoryProvider).getQueue();
});

/// 送审快照中经鉴权读取的媒体内容，按 (taskId, mediaId) 缓存。
final reviewMediaProvider = FutureProvider.autoDispose
    .family<ReviewMediaContent, (String, String)>((ref, key) {
      return ref.read(reviewRepositoryProvider).media(key.$1, key.$2);
    });

/// 工作台首页的领取命令（FX-111）。
class ReviewQueueCommands {
  final Ref _ref;

  ReviewQueueCommands(this._ref);

  /// 领取下一单（可按任务目的过滤）；队列为空返回 null 并刷新计数。
  ///
  /// 服务端判定已无审核角色时刷新授权，让入口按最新角色收起；错误仍抛给页面提示。
  Future<ReviewTaskItem?> claim({String purpose = ''}) async {
    try {
      final task = await _ref
          .read(reviewRepositoryProvider)
          .claim(purpose: purpose);
      // 队列为空说明首页计数已过时，顺带刷新。
      if (task == null) refreshQueue();
      return task;
    } on ApiException catch (error) {
      if (error.code == ErrorCodes.reviewRoleRequired && _ref.mounted) {
        _ref.invalidate(reviewerAccessProvider);
      }
      rethrow;
    }
  }

  /// 处理完任务返回首页时重新读取队列计数。
  void refreshQueue() {
    if (_ref.mounted) _ref.invalidate(reviewQueueProvider);
  }
}

/// 工作台首页的领取命令；随页面释放。
final reviewQueueCommandsProvider = Provider.autoDispose<ReviewQueueCommands>(
  ReviewQueueCommands.new,
);
