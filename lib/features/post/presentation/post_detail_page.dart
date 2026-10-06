import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../../comment/application/comment_notifier.dart';
import '../../comment/presentation/widgets/comment_input.dart';
import '../../comment/presentation/widgets/comment_item.dart';
import '../../interaction/application/interaction_notifier.dart';
import '../../profile/application/follow_controller.dart';
import '../../profile/application/user_profile_providers.dart';
import '../application/post_detail_provider.dart';
import '../../../core/router/app_routes.dart';

part 'post_detail_content.dart';
part 'post_detail_comments.dart';
part 'post_detail_actions.dart';

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

  bool _isOwnPost(GetPostResp post) {
    final auth = ref.read(authNotifierProvider);
    return jsonInt64IsPositive(auth.userId) &&
        jsonInt64Id(post.authorId) == jsonInt64Id(auth.userId);
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
                    _buildPostSection(post, comments),
                    ..._buildCommentSlivers(comments),
                  ],
                ),
              ),
              _buildCommentInput(post, comments),
            ],
          );
        },
      ),
    );
  }
}
