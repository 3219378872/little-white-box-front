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
    final authorKey = jsonInt64Id(post.authorId).toString();
    final following = auth.isAuthenticated && !own
        ? ref.watch(_authorFollowingProvider(authorKey)).value
        : false;
    final isFollowing = _followOverride ?? following ?? false;
    return Row(
      children: [
        Expanded(
          child: FTappable(
            onPress: () => context.push('/user/${jsonInt64Id(post.authorId)}'),
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
            onPress: _followBusy || (auth.isAuthenticated && following == null)
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
          FButton(
            size: FButtonSizeVariant.xs,
            mainAxisSize: MainAxisSize.min,
            selected: comments.sortBy == sort,
            variant: comments.sortBy == sort
                ? FButtonVariant.secondary
                : FButtonVariant.ghost,
            onPress: () => ref
                .read(commentNotifierProvider(widget.postId).notifier)
                .selectSort(sort),
            child: Text(label),
          ),
      ],
    );
  }
}
