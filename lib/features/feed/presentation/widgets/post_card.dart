import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../../sdk/data/gateway.dart';

class PostCard extends StatelessWidget {
  final PostItem post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final typography = theme.typography;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: FCard(
        builder: (context, style, _) => FTappable(
          onPress: () => context.push('/post/${post.id.toInt()}'),
          child: Padding(
            padding: style.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 作者信息行（更紧凑）
                Row(
                  children: [
                    GestureDetector(
                      onTap: () =>
                          context.push('/user/${post.authorId.toInt()}'),
                      child: CachedAvatar(
                          url: post.authorAvatar,
                          name: post.authorName,
                          radius: 14),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: typography.body.sm
                            .copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt),
                      style: typography.body.xs
                          .copyWith(color: colors.mutedForeground),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 标题
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    style: typography.body.md
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                // 内容摘要
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      post.content,
                      style: typography.body.sm
                          .copyWith(color: colors.mutedForeground),
                      maxLines: post.title.isNotEmpty ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // 图片展示（首张占满宽度）
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildImagePreview(context),
                ],
                // 标签
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: post.tags.map((tag) => _TagChip(tag: tag)).toList(),
                  ),
                ],
                // 底部统计
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statItem(
                        context, FLucideIcons.thumbsUp, post.likeCount.toInt()),
                    const SizedBox(width: 24),
                    _statItem(context, FLucideIcons.messageCircle,
                        post.commentCount.toInt()),
                    const Spacer(),
                    _statItem(
                        context, FLucideIcons.eye, post.viewCount.toInt()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final colors = context.theme.colors;
    final firstImage = post.images.first;
    final hasMore = post.images.length > 1;

    return ClipRRect(
      borderRadius: context.theme.style.borderRadius.md,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: firstImage,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: double.infinity,
              height: 180,
              color: colors.secondary,
            ),
            errorWidget: (_, _, _) => Container(
              width: double.infinity,
              height: 180,
              color: colors.secondary,
              child: Icon(
                FLucideIcons.image,
                color: colors.mutedForeground,
              ),
            ),
          ),
          if (hasMore)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${post.images.length - 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(BuildContext context, IconData icon, int count) {
    final theme = context.theme;
    final color = theme.colors.mutedForeground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
          style: theme.typography.body.xs.copyWith(color: color),
        ),
      ],
    );
  }

  String _formatTime(num timestamp) {
    final date =
        DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}-${date.day}';
  }
}

/// 标签 pill，视觉对齐 forui 的 secondary badge。
/// 不直接用 FBadge：其 IntrinsicWidth 布局在 Web/CanvasKit 下会把
/// CJK 文本压成单字宽（"美食" 只显示 "美"），故自绘规避。
class _TagChip extends StatelessWidget {
  final String tag;

  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(
        shape: RoundedSuperellipseBorder(
          borderRadius: theme.style.borderRadius.pill,
        ),
        color: theme.colors.secondary,
      ),
      child: Text(
        tag,
        style: theme.typography.body.xs.copyWith(
          color: theme.colors.secondaryForeground,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
