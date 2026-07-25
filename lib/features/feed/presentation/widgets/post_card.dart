import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/app_tag_badge.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../interaction/data/interaction_repository.dart';
import '../../../../sdk/data/gateway.dart';

final postCardInteractionRepositoryProvider = Provider<InteractionRepository>(
  (ref) => InteractionRepository(),
);

class PostCard extends ConsumerStatefulWidget {
  final PostItem post;

  const PostCard({super.key, required this.post});

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  late bool _isLiked;
  bool _isLikePending = false;
  late int _likeCount;

  PostItem get post => widget.post;

  @override
  void initState() {
    super.initState();
    _isLiked = post.isLiked;
    _likeCount = post.likeCount.toInt();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != post.id) {
      _isLiked = post.isLiked;
      _isLikePending = false;
      _likeCount = post.likeCount.toInt();
    } else if (!_isLikePending &&
        (oldWidget.post.isLiked != post.isLiked ||
            oldWidget.post.likeCount != post.likeCount)) {
      _isLiked = post.isLiked;
      _likeCount = post.likeCount.toInt();
    }
  }

  Future<void> _toggleLike() async {
    if (_isLikePending) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
      _isLikePending = true;
    });

    try {
      final repo = ref.read(postCardInteractionRepositoryProvider);
      if (wasLiked) {
        await repo.unlikeTarget(post.id.toInt(), 1);
      } else {
        await repo.likeTarget(post.id.toInt(), 1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _isLikePending = false);
      }
    }
  }

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
                    FTappable(
                      onPress: () =>
                          context.push('/user/${post.authorId.toInt()}'),
                      child: CachedAvatar(
                        url: post.authorAvatar,
                        name: post.authorName,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: typography.body.sm.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt),
                      style: typography.body.xs.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 标题
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    style: typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                // 内容摘要
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      post.content,
                      style: typography.body.sm.copyWith(
                        color: colors.mutedForeground,
                      ),
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
                    children: post.tags
                        .map((tag) => AppTagBadge(label: tag))
                        .toList(),
                  ),
                ],
                // 底部统计
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statItem(
                      context,
                      FLucideIcons.thumbsUp,
                      _likeCount,
                      key: ValueKey('post-like-${post.id.toInt()}'),
                      active: _isLiked,
                      onPress: _toggleLike,
                      semanticsLabel: _isLiked
                          ? '取消点赞，当前 $_likeCount 赞'
                          : '点赞，当前 $_likeCount 赞',
                    ),
                    const SizedBox(width: 24),
                    _statItem(
                      context,
                      FLucideIcons.messageCircle,
                      post.commentCount.toInt(),
                    ),
                    const Spacer(),
                    _statItem(
                      context,
                      FLucideIcons.eye,
                      post.viewCount.toInt(),
                    ),
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
              child: Icon(FLucideIcons.image, color: colors.mutedForeground),
            ),
          ),
          if (hasMore)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x8A000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${post.images.length - 1}',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context,
    IconData icon,
    int count, {
    Key? key,
    bool active = false,
    VoidCallback? onPress,
    String? semanticsLabel,
  }) {
    final theme = context.theme;
    final color = active ? theme.colors.primary : theme.colors.mutedForeground;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: theme.typography.body.xs.copyWith(color: color),
          ),
        ],
      ),
    );

    if (onPress == null) return content;
    return FTappable(
      key: key,
      onPress: onPress,
      semanticsLabel: semanticsLabel,
      child: content,
    );
  }

  String _formatTime(num timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}-${date.day}';
  }
}
