part of 'post_detail_page.dart';

extension _PostDetailActions on _PostDetailPageState {
  Widget _buildCommentInput(GetPostResp post, CommentState comments) {
    final interaction = ref.watch(interactionNotifierProvider(widget.postId));

    final isLiked = interaction.optimisticIsLiked ?? post.isLiked;
    final isFavorited = interaction.optimisticIsFavorited ?? post.isFavorited;
    final likeCount = post.likeCount.toInt() + interaction.likeCountDelta;
    final favCount =
        post.favoriteCount.toInt() + interaction.favoriteCountDelta;
    return CommentInput(
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
          _actionButton(
            icon: FLucideIcons.messageSquare,
            label: '${post.commentCount}',
            name: '查看评论',
            onTap: () => _selectSection(true),
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
    return FTappable(
      key: ValueKey('post-action-$name'),
      onPress: onTap,
      semanticsLabel: '$name $label',
      child: SizedBox(
        width: 44,
        height: 48,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: color),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.xs.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
