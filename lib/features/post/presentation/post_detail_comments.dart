import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../../../sdk/data/gateway.dart';
import '../../comment/application/comment_notifier.dart';
import '../../comment/presentation/widgets/comment_item.dart';

/// 评论列表为空时的占位：首屏失败给重试入口，否则引导用户发第一条评论。
///
/// 只在列表为空且不处于加载中时由详情页插入；登录拦截与聚焦输入框由页面回调完成。
class PostDetailCommentsEmpty extends StatelessWidget {
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onStartComment;

  const PostDetailCommentsEmpty({
    super.key,
    required this.hasError,
    required this.onRetry,
    required this.onStartComment,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return ErrorView(message: '评论加载失败', onRetry: onRetry);
    }
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pageInset,
        vertical: AppTheme.space6,
      ),
      child: Column(
        children: [
          Icon(
            FLucideIcons.messageCircle,
            size: 32,
            color: theme.colors.mutedForeground,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            '还没有评论',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FButton(
            key: const Key('post-first-comment'),
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress: onStartComment,
            child: const Text('来抢沙发'),
          ),
        ],
      ),
    );
  }
}

/// 顶级评论列表 sliver：逐条渲染评论与回复预览，尾部承载加载中、失败重试和「没有更多了」。
///
/// 回复展开、翻页与回复目标都经由页面回调写回 comment notifier。
class PostDetailCommentList extends StatelessWidget {
  final CommentState comments;
  final VoidCallback onRetry;
  final ValueChanged<CommentItem> onToggleReplies;
  final ValueChanged<CommentItem> onLoadMoreReplies;

  /// 设定回复目标：`thread` 是挂靠的顶级评论，`target` 是被 @ 的评论或回复。
  final void Function(CommentItem thread, CommentItem target) onReply;

  const PostDetailCommentList({
    super.key,
    required this.comments,
    required this.onRetry,
    required this.onToggleReplies,
    required this.onLoadMoreReplies,
    required this.onReply,
  });

  @override
  Widget build(BuildContext context) {
    // The API returns top-level comments with optional reply previews.
    final topLevel = comments.comments;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index >= topLevel.length) {
            // tail 位置：优先显示加载中，其次加载失败重试，最后"没有更多了"；
            // 列表为空时的失败已由上方 ErrorView 承担，尾部不再重复重试入口。
            return LoadMoreFooter(
              isLoading: comments.isLoading || comments.isLoadingMore,
              error: comments.error != null && topLevel.isNotEmpty
                  ? '评论加载失败'
                  : null,
              onRetry: onRetry,
              showEnd: !comments.hasMore && topLevel.isNotEmpty,
            );
          }
          return _buildComment(topLevel[index]);
        },
        childCount:
            topLevel.length +
            ((comments.isLoading ||
                    comments.isLoadingMore ||
                    comments.error != null ||
                    (!comments.hasMore && topLevel.isNotEmpty))
                ? 1
                : 0),
      ),
    );
  }

  // 单条顶级评论：展开态、回复加载态与已加载的楼中楼回复都从 notifier 状态派生。
  Widget _buildComment(CommentItem comment) {
    final id = jsonInt64Id(comment.id);
    final expanded = comments.expandedReplies.contains(id);
    final loading = comments.loadingReplies.contains(id);
    final replies = comments.threadReplies[id] ?? comment.replies;
    return CommentItemWidget(
      comment: comment,
      replies: replies,
      replyCount: comment.replyCount,
      expanded: expanded,
      loadingReplies: loading,
      hasMoreReplies:
          expanded && !loading && replies.length < comment.replyCount.toInt(),
      onToggleReplies: () => onToggleReplies(comment),
      onLoadMoreReplies: () => onLoadMoreReplies(comment),
      onReply: () => onReply(comment, comment),
      // 楼中楼扁平化：仍挂在同一顶级评论下，@被回复用户
      onReplyToReply: (target) => onReply(comment, target),
    );
  }
}
