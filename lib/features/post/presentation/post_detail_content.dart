part of 'post_detail_page.dart';

extension _PostDetailContent on _PostDetailPageState {
  Widget _buildPostSection(GetPostResp post, CommentState comments) {
    final theme = context.theme;
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              AppTheme.space2,
              AppTheme.pageInset,
              AppTheme.space6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space4),
                    child: Semantics(
                      header: true,
                      child: Text(
                        post.title,
                        style: theme.typography.display.md,
                      ),
                    ),
                  ),
                _buildPostAuthor(post),
                const SizedBox(height: AppTheme.space4),
                Text(
                  post.content,
                  style: theme.typography.body.md.copyWith(height: 1.75),
                ),
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space4),
                  ...post.images.map(
                    (url) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.space2),
                      child: ClipRRect(
                        borderRadius: AppTheme.imageRadius,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          width: double.infinity,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),
                ],
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.space3),
                  Wrap(
                    spacing: AppTheme.space2,
                    runSpacing: AppTheme.space2,
                    children: post.tags
                        .map((tag) => AppTagBadge(label: tag))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
          // Section band between the article and the discussion.
          SizedBox(height: 8, child: ColoredBox(color: theme.colors.muted)),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              AppTheme.space3,
              AppTheme.pageInset,
              AppTheme.space1,
            ),
            child: _buildCommentSort(post, comments),
          ),
        ],
      ),
    );
  }

  Widget _buildPostAuthor(GetPostResp post) {
    final theme = context.theme;
    final auth = ref.watch(authNotifierProvider);
    final own = _isOwnPost(post);
    final authorKey = jsonInt64Id(post.authorId);
    // 关注态未读到前（null）禁用按钮，避免基于猜测的值发出反向请求。
    final following = auth.isAuthenticated && !own
        ? ref.watch(userFollowingProvider(authorKey)).value
        : false;
    final follow = ref.watch(followControllerProvider(authorKey));
    final isFollowing = follow.following ?? following ?? false;
    return Row(
      children: [
        Expanded(
          child: FTappable(
            onPress: () => context.push(AppRoutes.userProfile(post.authorId)),
            child: Row(
              children: [
                CachedAvatar(
                  url: post.authorAvatar,
                  name: post.authorName,
                  radius: 20,
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatRelativeTime(post.createdAt, includeYear: true)}'
                        '  ·  ${post.viewCount} 次浏览',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!own) ...[
          const SizedBox(width: AppTheme.space2),
          FButton(
            key: const Key('post-follow-author'),
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            variant: isFollowing
                ? FButtonVariant.secondary
                : FButtonVariant.primary,
            prefix: Icon(
              isFollowing ? FLucideIcons.check : FLucideIcons.plus,
              size: 16,
            ),
            onPress:
                follow.isBusy || (auth.isAuthenticated && following == null)
                ? null
                : () => _toggleFollow(post, isFollowing),
            child: Text(isFollowing ? '已关注' : '关注'),
          ),
        ],
      ],
    );
  }

  Widget _buildCommentSort(GetPostResp post, CommentState comments) {
    final theme = context.theme;
    final count = post.commentCount.toInt();
    return Row(
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '评论'),
                if (count > 0)
                  TextSpan(
                    text: '  $count',
                    style: TextStyle(color: theme.colors.mutedForeground),
                  ),
              ],
            ),
            style: theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        for (final (sort, label) in const [(1, '最新'), (2, '最热')])
          _CommentSortChip(
            key: ValueKey('comment-sort-$sort'),
            label: label,
            selected: comments.sortBy == sort,
            onPress: () => ref
                .read(commentNotifierProvider(widget.postId).notifier)
                .selectSort(sort),
          ),
      ],
    );
  }
}

/// Comment sort toggle; the active order uses the accent like other
/// selected navigation so it does not read as a disabled control.
class _CommentSortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPress;

  const _CommentSortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    // One merged node: a button that reports its selected state. The notifier
    // ignores re-selecting the active order, so the chip is never disabled.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '按$label排序',
      onTap: onPress,
      excludeSemantics: true,
      child: FTappable(
        onPress: onPress,
        builder: (context, variants, _) {
          final hovered =
              !selected &&
              (variants.contains(FTappableVariant.hovered) ||
                  variants.contains(FTappableVariant.pressed));
          return Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accentSoft(colors)
                  : hovered
                  ? colors.secondary
                  : null,
              borderRadius: AppTheme.controlRadius,
            ),
            child: Text(
              label,
              style: theme.typography.body.sm.copyWith(
                color: selected ? colors.primary : colors.mutedForeground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}
