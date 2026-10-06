import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../../comment/application/comment_notifier.dart';
import '../../interaction/application/interaction_notifier.dart';
import '../../profile/application/follow_controller.dart';
import '../application/post_detail_provider.dart';
import 'post_detail_actions.dart';
import 'post_detail_comments.dart';
import 'post_detail_content.dart';

/// 帖子详情页：正文、评论列表与底部评论栏。
///
/// 页面持有滚动与评论输入焦点，并集中处理需要登录拦截、错误提示的写操作；
/// 子组件只通过显式参数和回调与页面交互。
class PostDetailPage extends ConsumerStatefulWidget {
  final String postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  /// Scroll offset after which the title moves into the header.
  static const _titleCollapseOffset = 72.0;

  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _commentFocus = FocusNode();
  bool _showHeaderTitle = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _commentFocus.dispose();
    super.dispose();
  }

  // 滚动驱动两件事：标题移入顶栏，以及接近底部时加载下一页评论。
  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final showTitle = _scrollCtrl.offset > _titleCollapseOffset;
    if (showTitle != _showHeaderTitle) {
      setState(() => _showHeaderTitle = showTitle);
    }
    final threshold = _scrollCtrl.position.maxScrollExtent - 300;
    if (_scrollCtrl.position.pixels >= threshold) {
      ref.read(commentNotifierProvider(widget.postId).notifier).loadMore();
    }
  }

  // 点赞/收藏：匿名先去登录，乐观更新与回滚在 interaction notifier 内完成。
  Future<void> _toggleLike(GetPostResp post) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
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

  // 与个人页共用 follow controller：匿名先去登录，乐观更新与回滚在 controller 内完成。
  Future<void> _toggleFollow(GetPostResp post, bool isFollowing) async {
    final follow = followControllerProvider(jsonInt64Id(post.authorId));
    if (ref.read(follow).isBusy) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    try {
      await ref.read(follow.notifier).toggle(isFollowing);
    } catch (e) {
      if (!mounted) return;
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    }
  }

  Future<void> _toggleFavorite(GetPostResp post) async {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
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

  // 展开/收起与翻页楼中楼回复，失败只提示不打断阅读。
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

  // 提交评论；失败时 rethrow 让输入框保留草稿。
  Future<void> _submitComment(String content) async {
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      context.push(AppRoutes.login);
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

  // 首条评论引导：匿名先去登录，已登录则聚焦底部输入框。
  void _startFirstComment() {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    _commentFocus.requestFocus();
  }

  // 回调触发时再读取 notifier，避免持有过期实例。
  CommentNotifier get _commentNotifier =>
      ref.read(commentNotifierProvider(widget.postId).notifier);

  // 设定回复目标：始终挂在顶级评论 thread 下，@ 的是 target 的作者。
  void _replyTo(CommentItem thread, CommentItem target) {
    _commentNotifier.setReplyTarget(
      userName: target.userName,
      parentId: thread.id,
      userId: target.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(postDetailProvider(widget.postId));
    final post = postAsync.value;
    final theme = context.theme;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        // The title moves into the header once the in-page title scrolls
        // away; it is not built before that so it is never announced twice.
        title: _showHeaderTitle && post != null
            ? Text(
                post.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.md.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              )
            : const SizedBox.shrink(),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go(AppRoutes.feed),
          ),
        ],
      ),
      child: postAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(postDetailProvider(widget.postId)),
        ),
        data: (post) {
          final comments = ref.watch(commentNotifierProvider(widget.postId));

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    // 正文与评论排序栏
                    SliverToBoxAdapter(
                      child: PostDetailArticle(
                        post: post,
                        commentSortBy: comments.sortBy,
                        onSelectSort: (sort) =>
                            _commentNotifier.selectSort(sort),
                        onToggleFollow: (isFollowing) =>
                            _toggleFollow(post, isFollowing),
                      ),
                    ),
                    // 评论为空且不在加载时显示空态或首屏失败重试
                    if (comments.comments.isEmpty &&
                        !comments.isLoading &&
                        !comments.isLoadingMore)
                      SliverToBoxAdapter(
                        child: PostDetailCommentsEmpty(
                          hasError: comments.error != null,
                          onRetry: () => _commentNotifier.retry(),
                          onStartComment: _startFirstComment,
                        ),
                      ),
                    PostDetailCommentList(
                      comments: comments,
                      onRetry: () => _commentNotifier.retry(),
                      onToggleReplies: _onToggleReplies,
                      onLoadMoreReplies: _onLoadMoreReplies,
                      onReply: _replyTo,
                    ),
                  ],
                ),
              ),
              PostDetailCommentBar(
                postId: widget.postId,
                post: post,
                focusNode: _commentFocus,
                replyTo: comments.replyToUser,
                onSubmit: _submitComment,
                onToggleLike: () => _toggleLike(post),
                onToggleFavorite: () => _toggleFavorite(post),
              ),
            ],
          );
        },
      ),
    );
  }
}
