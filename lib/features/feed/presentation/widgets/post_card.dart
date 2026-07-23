import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../../sdk/data/gateway.dart';

class PostCard extends StatelessWidget {
  final PostItem post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/post/${post.id.toInt()}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 作者信息行（更紧凑）
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.push('/user/${post.authorId.toInt()}'),
                    child: CachedAvatar(
                        url: post.authorAvatar,
                        name: post.authorName,
                        radius: 14),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.authorName,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    _formatTime(post.createdAt),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 标题
              if (post.title.isNotEmpty)
                Text(
                  post.title,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              // 内容摘要
              if (post.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    post.content,
                    style: theme.textTheme.bodyMedium,
                    maxLines: post.title.isNotEmpty ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              // 图片展示（首张占满宽度）
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildImagePreview(theme),
              ],
              // 标签
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: post.tags
                      .map((tag) => Chip(
                            label: Text(tag),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            labelStyle: theme.textTheme.labelSmall,
                          ))
                      .toList(),
                ),
              ],
              // 底部统计
              const SizedBox(height: 10),
              Row(
                children: [
                  _statItem(context, Icons.thumb_up_outlined, post.likeCount.toInt()),
                  const SizedBox(width: 24),
                  _statItem(context, Icons.chat_bubble_outline, post.commentCount.toInt()),
                  const Spacer(),
                  _statItem(context, Icons.remove_red_eye_outlined, post.viewCount.toInt()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    final firstImage = post.images.first;
    final hasMore = post.images.length > 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
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
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            errorWidget: (_, _, _) => Container(
              width: double.infinity,
              height: 180,
              color: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.image_outlined,
                color: theme.colorScheme.outline,
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
    final color = Theme.of(context).colorScheme.outline;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color),
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
