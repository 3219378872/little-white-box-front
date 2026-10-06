part of 'post_detail_page.dart';

extension _PostDetailComments on _PostDetailPageState {
  List<Widget> _buildCommentSlivers(CommentState comments) {
    final theme = context.theme;
    // The API returns top-level comments with optional reply previews.
    final topLevel = comments.comments;
    return [
      // 评论列表
      if (topLevel.isEmpty && !comments.isLoading)
        SliverToBoxAdapter(
          child: comments.hasError
              ? ErrorView(
                  message: '评论加载失败',
                  onRetry: () => ref
                      .read(commentNotifierProvider(widget.postId).notifier)
                      .retry(),
                )
              : _buildEmptyComments(),
        ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= topLevel.length) {
              // tail 位置：优先显示加载中，其次加载失败重试，最后"没有更多了"
              if (comments.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: LoadingView(),
                );
              }
              if (comments.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: FButton(
                      variant: .ghost,
                      size: .sm,
                      mainAxisSize: MainAxisSize.min,
                      onPress: () => ref
                          .read(commentNotifierProvider(widget.postId).notifier)
                          .retry(),
                      child: const Text('评论加载失败，重试'),
                    ),
                  ),
                );
              }
              if (!comments.hasMore && topLevel.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      '— 没有更多了 —',
                      style: TextStyle(
                        color: theme.colors.mutedForeground,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }
              return null;
            }
            return _buildComment(comments, topLevel[index]);
          },
          childCount:
              topLevel.length +
              ((comments.isLoading ||
                      comments.hasError ||
                      (!comments.hasMore && topLevel.isNotEmpty))
                  ? 1
                  : 0),
        ),
      ),
    ];
  }

  Widget _buildEmptyComments() {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.pageInset,
        vertical: AppTheme.space6,
      ),
      child: Column(
        children: [
          Icon(
            FLucideIcons.messageCircle,
            size: 32,
            color: theme.colors.mutedForeground,
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            '还没有评论',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FButton(
            key: const Key('post-first-comment'),
            variant: FButtonVariant.outline,
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            onPress: () {
              if (!ref.read(authNotifierProvider).isAuthenticated) {
                context.push('/auth/login');
                return;
              }
              _commentFocus.requestFocus();
            },
            child: const Text('来抢沙发'),
          ),
        ],
      ),
    );
  }

  Widget _buildComment(CommentState comments, CommentItem comment) {
    final id = jsonInt64Id(comment.id);
    final expanded = comments.expandedReplies.contains(id);
    final loading = comments.loadingReplies.contains(id);
    final replies = comments.threadReplies[id] ?? comment.replies;
    return CommentItemWidget(
      comment: comment,
      replies: replies,
      replyCount: comment.replyCount,
      expanded: expanded,
      loadingReplies: loading,
      hasMoreReplies:
          expanded && !loading && replies.length < comment.replyCount.toInt(),
      onToggleReplies: () => _onToggleReplies(comment),
      onLoadMoreReplies: () => _onLoadMoreReplies(comment),
      onReply: () {
        ref
            .read(commentNotifierProvider(widget.postId).notifier)
            .setReplyTarget(
              userName: comment.userName,
              parentId: comment.id,
              userId: comment.userId,
            );
      },
      onReplyToReply: (target) {
        // 楼中楼扁平化：仍挂在同一顶级评论下，@被回复用户
        ref
            .read(commentNotifierProvider(widget.postId).notifier)
            .setReplyTarget(
              userName: target.userName,
              parentId: comment.id,
              userId: target.userId,
            );
      },
    );
  }
}
