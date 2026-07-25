import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../../sdk/data/gateway.dart';

class CommentItemWidget extends StatelessWidget {
  final CommentItem comment;
  final List<CommentItem> replies;
  final VoidCallback? onReply;
  final VoidCallback? onLike;

  const CommentItemWidget({
    super.key,
    required this.comment,
    this.replies = const [],
    this.onReply,
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
          // 子评论
          if (replies.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.secondary.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: replies
                      .take(3)
                      .map((r) => _buildComment(context, r, isReply: true))
                      .toList(),
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
                      _formatTime(item.createdAt),
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
                      onPress: onLike,
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
      ),
    );
  }

  String _formatTime(num timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}-${date.day}';
  }
}
