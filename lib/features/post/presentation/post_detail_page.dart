import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../sdk/data/gateway.dart';
import '../../assistant/application/assistant_notifier.dart';
import '../../auth/application/auth_notifier.dart';
import '../../comment/application/comment_notifier.dart';
import '../../comment/presentation/widgets/comment_input.dart';
import '../../comment/presentation/widgets/comment_item.dart';
import '../../interaction/application/interaction_notifier.dart';
import '../data/post_repository.dart';

final _postRepoProvider = Provider((ref) => PostRepository());

final _postDetailProvider = FutureProvider.autoDispose
    .family<GetPostResp, String>((ref, postId) {
      ref.watch(authSessionIdentityProvider);
      return ref.read(_postRepoProvider).getPostDetail(postId);
    });

class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  final ScrollController _scrollCtrl = ScrollController();
  bool _commentsOnly = false;

  void _selectSection(bool commentsOnly) {
    if (_commentsOnly == commentsOnly) {
      if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
      return;
    }
    setState(() => _commentsOnly = commentsOnly);
    if (_scrollCtrl.hasClients) _scrollCtrl.jumpTo(0);
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final threshold = _scrollCtrl.position.maxScrollExtent - 300;
    if (_scrollCtrl.position.pixels >= threshold) {
      ref.read(commentNotifierProvider(widget.postId).notifier).loadMore();
    }
  }

  Future<void> _toggleLike(GetPostResp post) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    try {
      await ref
          .read(interactionNotifierProvider(widget.postId).notifier)
          .toggleLike(post);
    } catch (e) {
      if (mounted) {
        showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _toggleFavorite(GetPostResp post) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    try {
      await ref
          .read(interactionNotifierProvider(widget.postId).notifier)
          .toggleFavorite(post);
    } catch (e) {
      if (mounted) {
        showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _onToggleReplies(CommentItem comment) async {
    try {
      await ref
          .read(commentNotifierProvider(widget.postId).notifier)
          .toggleReplies(comment);
    } catch (e) {
      if (mounted) {
        showAppError(context, '回复加载失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _onLoadMoreReplies(CommentItem comment) async {
    try {
      await ref
          .read(commentNotifierProvider(widget.postId).notifier)
          .loadMoreReplies(comment);
    } catch (e) {
      if (mounted) {
        showAppError(context, '回复加载失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _createWatch({
    required String conditionType,
    required String targetType,
    required Object targetId,
    required Object authorId,
  }) async {
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      throw const ApiException('请先登录');
    }
    if (jsonInt64IsPositive(auth.userId) &&
        jsonInt64Id(authorId) == jsonInt64Id(auth.userId)) {
      if (mounted) showAppError(context, '不能关注自己的动态');
      return;
    }
    final consent = ref.read(agentConsentNotifierProvider.notifier);
    await consent.ensureLoaded();
    if (!mounted) return;
    final status = ref.read(agentConsentNotifierProvider);
    if (!status.granted || status.needsUpgrade) {
      context.push('/messages/assistant');
      return;
    }
    try {
      await ref
          .read(assistantRepositoryProvider)
          .createWatch(
            conditionType: conditionType,
            targetType: targetType,
            targetId: targetId,
          );
      if (mounted) showAppSuccess(context, '已创建追踪');
    } catch (e) {
      if (mounted) {
        showAppError(context, '创建追踪失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _submitComment(String content) async {
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      throw const ApiException('请先登录');
    }
    try {
      await ref
          .read(commentNotifierProvider(widget.postId).notifier)
          .submit(content);
    } catch (e) {
      if (mounted) {
        showAppError(context, '评论失败: ${friendlyErrorMessage(e)}');
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authNotifierProvider);
    final postAsync = ref.watch(_postDetailProvider(widget.postId));
    final theme = context.theme;

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [_sectionTab('正文', false), _sectionTab('评论', true)],
        ),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/feed'),
          ),
        ],
      ),
      child: postAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(_postDetailProvider(widget.postId)),
        ),
        data: (post) {
          final interaction = ref.watch(
            interactionNotifierProvider(widget.postId),
          );
          final comments = ref.watch(commentNotifierProvider(widget.postId));

          final isLiked = interaction.optimisticIsLiked ?? post.isLiked;
          final isFavorited =
              interaction.optimisticIsFavorited ?? post.isFavorited;
          final likeCount = post.likeCount.toInt() + interaction.likeCountDelta;
          final favCount =
              post.favoriteCount.toInt() + interaction.favoriteCountDelta;
          // 后端契约：列表只含顶级评论，子评论经内嵌预览 + 楼中楼接口按需加载
          final topLevel = comments.comments;

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    // 帖子内容
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_commentsOnly) ...[
                              if (post.title.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    post.title,
                                    style: theme.typography.display.sm,
                                  ),
                                ),
                              // 作者
                              FTappable(
                                onPress: () => context.push(
                                  '/user/${jsonInt64Id(post.authorId)}',
                                ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            post.authorName,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.typography.body.md
                                                .copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          Text(
                                            formatRelativeTime(
                                              post.createdAt,
                                              includeYear: true,
                                            ),
                                            style: theme.typography.body.xs
                                                .copyWith(
                                                  color: theme
                                                      .colors
                                                      .mutedForeground,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              // 正文
                              Text(
                                post.content,
                                style: theme.typography.body.lg,
                              ),
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
                              if (ref
                                  .watch(authNotifierProvider)
                                  .isAuthenticated) ...[
                                const SizedBox(height: 12),
                                Wrap(
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
                                ),
                              ],
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: FDivider(),
                              ),
                            ],
                            // 评论区标题
                            Row(
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
                                      .read(
                                        commentNotifierProvider(
                                          widget.postId,
                                        ).notifier,
                                      )
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
                                      .read(
                                        commentNotifierProvider(
                                          widget.postId,
                                        ).notifier,
                                      )
                                      .selectSort(2),
                                  child: const Text('最热'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 评论列表
                    if (topLevel.isEmpty && !comments.isLoading)
                      SliverToBoxAdapter(
                        child: comments.hasError
                            ? ErrorView(
                                message: '评论加载失败',
                                onRetry: () => ref
                                    .read(
                                      commentNotifierProvider(
                                        widget.postId,
                                      ).notifier,
                                    )
                                    .retry(),
                              )
                            : const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(child: Text('还没有评论')),
                              ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= topLevel.length) {
                            // tail 位置：优先显示加载中，其次加载失败重试，最后"没有更多了"
                            if (comments.isLoading) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: FCircularProgress()),
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
                                        .read(
                                          commentNotifierProvider(
                                            widget.postId,
                                          ).notifier,
                                        )
                                        .retry(),
                                    child: const Text('评论加载失败，重试'),
                                  ),
                                ),
                              );
                            }
                            if (!comments.hasMore && topLevel.isNotEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
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
                          final comment = topLevel[index];
                          final id = jsonInt64Id(comment.id);
                          final expanded = comments.expandedReplies.contains(
                            id,
                          );
                          final loading = comments.loadingReplies.contains(id);
                          final replies =
                              comments.threadReplies[id] ?? comment.replies;
                          return CommentItemWidget(
                            comment: comment,
                            replies: replies,
                            replyCount: comment.replyCount,
                            expanded: expanded,
                            loadingReplies: loading,
                            hasMoreReplies:
                                expanded &&
                                !loading &&
                                replies.length < comment.replyCount.toInt(),
                            onToggleReplies: () => _onToggleReplies(comment),
                            onLoadMoreReplies: () =>
                                _onLoadMoreReplies(comment),
                            onReply: () {
                              ref
                                  .read(
                                    commentNotifierProvider(
                                      widget.postId,
                                    ).notifier,
                                  )
                                  .setReplyTarget(
                                    userName: comment.userName,
                                    parentId: comment.id,
                                    userId: comment.userId,
                                  );
                            },
                            onReplyToReply: (target) {
                              // 楼中楼扁平化：仍挂在同一顶级评论下，@被回复用户
                              ref
                                  .read(
                                    commentNotifierProvider(
                                      widget.postId,
                                    ).notifier,
                                  )
                                  .setReplyTarget(
                                    userName: target.userName,
                                    parentId: comment.id,
                                    userId: target.userId,
                                  );
                            },
                          );
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
                  ],
                ),
              ),
              CommentInput(
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
              ),
            ],
          );
        },
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

  Widget _sectionTab(String label, bool commentsOnly) {
    final selected = _commentsOnly == commentsOnly;
    return Semantics(
      selected: selected,
      child: FTappable(
        onPress: () => _selectSection(commentsOnly),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: selected
                    ? context.theme.colors.foreground
                    : const Color(0x00000000),
              ),
            ),
          ),
          child: Text(
            label,
            style: context.theme.typography.body.lg.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? context.theme.colors.foreground
                  : context.theme.colors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
