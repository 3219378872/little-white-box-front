import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/formatters/time_formatter.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../../sdk/data/gateway.dart';

class CommentItemWidget extends StatelessWidget {
  final CommentItem comment;

  /// 展开后展示的回复列表（首屏来自内嵌预览，加载更多后为全量分页结果）
  final List<CommentItem> replies;

  /// 楼中楼回复总数（决定是否显示"共 N 条回复"入口）
  final num replyCount;
  final bool expanded;
  final bool loadingReplies;
  final bool hasMoreReplies;
  final VoidCallback? onToggleReplies;
  final VoidCallback? onLoadMoreReplies;
  final VoidCallback? onReply;
  final ValueChanged<CommentItem>? onReplyToReply;
  final VoidCallback? onLike;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.replies = const [],
    this.replyCount = 0,
    this.expanded = false,
    this.loadingReplies = false,
    this.hasMoreReplies = false,
    this.onToggleReplies,
    this.onLoadMoreReplies,
    this.onReply,
    this.onReplyToReply,
    this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComment(context, comment, isReply: false),
          if (replyCount > 0 || replies.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: FTappable(
                onPress: onToggleReplies,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      expanded
                          ? FLucideIcons.chevronUp
                          : FLucideIcons.chevronDown,
                      size: 14,
                      color: colors.mutedForeground,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      expanded ? '收起回复' : '共 $replyCount 条回复',
                      style: context.theme.typography.body.xs.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (expanded && replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    ...replies.map(
                      (r) => _buildComment(
                        context,
                        r,
                        isReply: true,
                        onReply: () => onReplyToReply?.call(r),
                      ),
                    ),
                    if (loadingReplies)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: FCircularProgress(size: .xs),
                      )
                    else if (hasMoreReplies)
                      FTappable(
                        onPress: onLoadMoreReplies,
                        child: Text(
                          '加载更多回复',
                          style: context.theme.typography.body.xs.copyWith(
                            color: context.theme.colors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const FDivider(),
        ],
      ),
    );
  }

  Widget _buildComment(
    BuildContext context,
    CommentItem item, {
    required bool isReply,
    VoidCallback? onReply,
  }) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    return Padding(
      padding: EdgeInsets.only(bottom: isReply ? 8 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CachedAvatar(
            url: item.userAvatar,
            name: item.userName,
            radius: isReply ? 12 : 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.userName,
                      style: theme.typography.body.sm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatRelativeTime(item.createdAt),
                      style: theme.typography.body.xs.copyWith(color: muted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(item.content, style: theme.typography.body.sm),
                const SizedBox(height: 4),
                Row(
                  children: [
                    FTappable(
                      onPress: isReply ? null : onLike,
                      child: Row(
                        children: [
                          Icon(FLucideIcons.thumbsUp, size: 14, color: muted),
                          const SizedBox(width: 4),
                          Text(
                            '${item.likeCount}',
                            style: theme.typography.body.xs.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    FTappable(
                      onPress: onReply ?? (isReply ? null : this.onReply),
                      child: Row(
                        children: [
                          Icon(FLucideIcons.reply, size: 14, color: muted),
                          const SizedBox(width: 4),
                          Text(
                            '回复',
                            style: theme.typography.body.xs.copyWith(
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
