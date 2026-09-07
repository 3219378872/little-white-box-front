part of 'post_detail_page.dart';

extension _PostDetailContent on _PostDetailPageState {
  Widget _buildPostSection(GetPostResp post, CommentState comments) {
    final theme = context.theme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_commentsOnly) ...[
              if (post.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(post.title, style: theme.typography.display.sm),
                ),
              // 作者
              _buildPostAuthor(post),
              const SizedBox(height: 16),
              // 正文
              Text(post.content, style: theme.typography.body.lg),
              // 图片
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: 16),
                ...post.images.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: theme.style.borderRadius.md,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),
                ),
              ],
              // 标签
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: post.tags
                      .map((tag) => AppTagBadge(label: tag))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                '${post.viewCount} 次浏览',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              if (ref.watch(authNotifierProvider).isAuthenticated) ...[
                const SizedBox(height: 12),
                _buildPostWatchActions(post),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: FDivider(),
              ),
            ],
            // 评论区标题
            _buildCommentSort(comments),
          ],
        ),
      ),
    );
  }

  Widget _buildPostAuthor(GetPostResp post) {
    final theme = context.theme;
    return FTappable(
      onPress: () => context.push('/user/${jsonInt64Id(post.authorId)}'),
      child: Row(
        children: [
          CachedAvatar(
            url: post.authorAvatar,
            name: post.authorName,
            radius: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.authorName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatRelativeTime(post.createdAt, includeYear: true),
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostWatchActions(GetPostResp post) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FButton(
          key: const Key('post-watch-author'),
          variant: .outline,
          size: .sm,
          onPress: () => _createWatch(
            conditionType: 'author_new_post',
            targetType: 'author',
            targetId: post.authorId,
            authorId: post.authorId,
          ),
          child: const Text('盯作者'),
        ),
        FButton(
          key: const Key('post-watch-revision'),
          variant: .outline,
          size: .sm,
          onPress: () => _createWatch(
            conditionType: 'post_revised',
            targetType: 'post',
            targetId: post.id,
            authorId: post.authorId,
          ),
          child: const Text('盯本帖修订'),
        ),
      ],
    );
  }

  Widget _buildCommentSort(CommentState comments) {
    final theme = context.theme;
    return Row(
      children: [
        Text('评论', style: theme.typography.body.md),
        const Spacer(),
        FButton(
          size: .xs,
          mainAxisSize: MainAxisSize.min,
          variant: comments.sortBy == 1
              ? FButtonVariant.secondary
              : FButtonVariant.ghost,
          onPress: () => ref
              .read(commentNotifierProvider(widget.postId).notifier)
              .selectSort(1),
          child: const Text('最新'),
        ),
        const SizedBox(width: 4),
        FButton(
          size: .xs,
          mainAxisSize: MainAxisSize.min,
          variant: comments.sortBy == 2
              ? FButtonVariant.secondary
              : FButtonVariant.ghost,
          onPress: () => ref
              .read(commentNotifierProvider(widget.postId).notifier)
              .selectSort(2),
          child: const Text('最热'),
        ),
      ],
    );
  }
}
