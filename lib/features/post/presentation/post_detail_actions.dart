part of 'post_detail_page.dart';

extension _PostDetailActions on _PostDetailPageState {
  Widget _buildCommentInput(GetPostResp post, CommentState comments) {
    final interaction = ref.watch(interactionNotifierProvider(widget.postId));

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
      focusNode: _commentFocus,
      replyTo: comments.replyToUser,
      onSubmit: _submitComment,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _actionButton(
            icon: FLucideIcons.thumbsUp,
            label: '$likeCount',
            name: '点赞',
            active: isLiked,
            onTap: () => _toggleLike(post),
          ),
          _actionButton(
            icon: FLucideIcons.star,
            label: '$favCount',
            name: '收藏',
            active: isFavorited,
            onTap: () => _toggleFavorite(post),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required String name,
    bool active = false,
    required VoidCallback onTap,
  }) {
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
