import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/formatters/time_formatter.dart';
import '../../../../core/theme/app_theme.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildComment(context, comment),
          if (replyCount > 0 || replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 44, top: 8, bottom: 12),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.muted,
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (final reply in expanded ? replies : replies.take(2))
                      FTappable(
                        onPress: onReplyToReply == null
                            ? null
                            : () => onReplyToReply!(reply),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${reply.userName}: ',
                                    style: TextStyle(
                                      color:
                                          colors.brightness == Brightness.dark
                                          ? colors.foreground
                                          : AppTheme.link,
                                    ),
                                  ),
                                  TextSpan(text: reply.content),
                                ],
                              ),
                              style: context.theme.typography.body.sm,
                              maxLines: expanded ? null : 3,
                              overflow: expanded
                                  ? TextOverflow.visible
                                  : TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    if (loadingReplies)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: FCircularProgress(size: .xs),
                      )
                    else if (expanded && hasMoreReplies)
                      FTappable(
                        onPress: onLoadMoreReplies,
                        child: Text(
                          '加载更多回复',
                          style: context.theme.typography.body.xs.copyWith(
                            color: context.theme.colors.primary,
                          ),
                        ),
                      ),
                    FTappable(
                      onPress: onToggleReplies,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                expanded ? '收起回复' : '共 $replyCount 条回复',
                                style: context.theme.typography.body.sm
                                    .copyWith(color: colors.mutedForeground),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              expanded
                                  ? FLucideIcons.chevronUp
                                  : FLucideIcons.chevronDown,
                              size: 14,
                              color: colors.mutedForeground,
                            ),
                          ],
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

  Widget _buildComment(BuildContext context, CommentItem item) {
    final theme = context.theme;
    final muted = theme.colors.mutedForeground;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CachedAvatar(url: item.userAvatar, name: item.userName, radius: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.userName,
                      style: theme.typography.body.sm.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FTappable(
                    onPress: onLike,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FLucideIcons.thumbsUp, size: 16, color: muted),
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
                ],
              ),
              Text(
                formatRelativeTime(item.createdAt),
                style: theme.typography.body.xs.copyWith(color: muted),
              ),
              const SizedBox(height: 8),
              Text(item.content, style: theme.typography.body.md),
              const SizedBox(height: 4),
              Row(
                children: [
                  FTappable(
                    onPress: onReply,
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
    );
  }
}
