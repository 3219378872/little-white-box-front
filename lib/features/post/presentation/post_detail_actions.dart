import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../sdk/data/gateway.dart';
import '../../comment/presentation/widgets/comment_input.dart';
import '../../interaction/application/interaction_notifier.dart';

/// 详情页底部评论栏：评论输入框右侧附点赞、收藏两个计数按钮。
///
/// 点赞/收藏的乐观态由 interaction notifier 维护，故本组件自行订阅；
/// 登录拦截、提交评论与失败提示由页面回调处理。
class PostDetailCommentBar extends ConsumerWidget {
  final String postId;
  final GetPostResp post;
  final FocusNode focusNode;

  /// 正在回复的用户名；为空时是对帖子本身评论。
  final String? replyTo;
  final Future<void> Function(String content) onSubmit;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleFavorite;

  const PostDetailCommentBar({
    super.key,
    required this.postId,
    required this.post,
    required this.focusNode,
    required this.replyTo,
    required this.onSubmit,
    required this.onToggleLike,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final interaction = ref.watch(interactionNotifierProvider(postId));

    // 乐观态优先，未操作过时回落到帖子详情返回的值。
    final isLiked = interaction.optimisticIsLiked ?? post.isLiked;
    final isFavorited = interaction.optimisticIsFavorited ?? post.isFavorited;
    final likeCount = interaction.likeCountFor(
      count: post.likeCount.toInt(),
      isLiked: post.isLiked,
    );
    final favCount = interaction.favoriteCountFor(
      count: post.favoriteCount.toInt(),
      isFavorited: post.isFavorited,
    );
    return CommentInput(
      focusNode: focusNode,
      replyTo: replyTo,
      onSubmit: onSubmit,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PostActionButton(
            icon: FLucideIcons.thumbsUp,
            label: '$likeCount',
            name: '点赞',
            active: isLiked,
            onTap: onToggleLike,
          ),
          _PostActionButton(
            icon: FLucideIcons.star,
            label: '$favCount',
            name: '收藏',
            active: isFavorited,
            onTap: onToggleFavorite,
          ),
        ],
      ),
    );
  }
}

// 评论栏内的计数按钮：激活态用主色，计数为 0 时只显示图标。
class _PostActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String name;
  final bool active;
  final VoidCallback onTap;

  const _PostActionButton({
    required this.icon,
    required this.label,
    required this.name,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final color = active ? theme.colors.primary : theme.colors.mutedForeground;
    final count = int.tryParse(label) ?? 0;
    return FTappable(
      key: ValueKey('post-action-$name'),
      onPress: onTap,
      semanticsLabel: '$name $label',
      selected: active,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              // Zero counts add no information; the icon names the action.
              if (count > 0) ...[
                const SizedBox(width: AppTheme.space1),
                Text(
                  label,
                  maxLines: 1,
                  style: theme.typography.body.sm.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
