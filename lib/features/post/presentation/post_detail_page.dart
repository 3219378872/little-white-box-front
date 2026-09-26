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
import '../../../sdk/data/gateway.dart';
import '../../assistant/application/assistant_notifier.dart';
import '../../auth/application/auth_notifier.dart';
import '../../comment/application/comment_notifier.dart';
import '../../comment/presentation/widgets/comment_input.dart';
import '../../comment/presentation/widgets/comment_item.dart';
import '../../interaction/application/interaction_notifier.dart';
import '../../profile/data/user_repository.dart';
import '../data/post_repository.dart';

part 'post_detail_content.dart';
part 'post_detail_comments.dart';
part 'post_detail_actions.dart';

final _postRepoProvider = Provider((ref) => PostRepository());

final _authorRepoProvider = Provider((ref) => UserRepository());

/// Whether the signed-in user follows [authorId]; reuses the profile endpoint.
final _authorFollowingProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, authorId) async {
      ref.watch(authSessionIdentityProvider);
      final user = await ref.read(_authorRepoProvider).getUserProfile(authorId);
      return user.isFollowing;
    });

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
  /// Scroll offset after which the title moves into the header.
  static const _titleCollapseOffset = 72.0;

  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _commentFocus = FocusNode();
  bool _showHeaderTitle = false;
  bool? _followOverride;
  bool _followBusy = false;

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

  Future<void> _toggleFollow(GetPostResp post, bool isFollowing) async {
    if (_followBusy) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    final repo = ref.read(_authorRepoProvider);
    final previous = _followOverride;
    setState(() {
      _followOverride = !isFollowing;
      _followBusy = true;
    });
    try {
      if (isFollowing) {
        await repo.unfollowUser(post.authorId);
      } else {
        await repo.followUser(post.authorId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _followOverride = previous);
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _followBusy = false);
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

  bool _isOwnPost(GetPostResp post) {
    final auth = ref.read(authNotifierProvider);
    return jsonInt64IsPositive(auth.userId) &&
        jsonInt64Id(post.authorId) == jsonInt64Id(auth.userId);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final postAsync = ref.watch(_postDetailProvider(widget.postId));
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
                context.canPop() ? context.pop() : context.go('/feed'),
          ),
        ],
        suffixes: [
          if (post != null && auth.isAuthenticated && !_isOwnPost(post))
            _buildMoreMenu(post),
        ],
      ),
      child: postAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(_postDetailProvider(widget.postId)),
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

  Widget _buildMoreMenu(GetPostResp post) {
    return FPopoverMenu(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      menuBuilder: (context, controller, _) => [
        FItemGroup(
          children: [
            FItem(
              key: const Key('post-watch-author'),
              prefix: const Icon(FLucideIcons.userRoundPlus),
              title: const Text('追踪作者新帖'),
              subtitle: const Text('作者发新帖时由 Agent 提醒'),
              onPress: () {
                controller.hide();
                _createWatch(
                  conditionType: 'author_new_post',
                  targetType: 'author',
                  targetId: post.authorId,
                  authorId: post.authorId,
                );
              },
            ),
            FItem(
              key: const Key('post-watch-revision'),
              prefix: const Icon(FLucideIcons.history),
              title: const Text('追踪本帖修订'),
              subtitle: const Text('正文更新时由 Agent 提醒'),
              onPress: () {
                controller.hide();
                _createWatch(
                  conditionType: 'post_revised',
                  targetType: 'post',
                  targetId: post.id,
                  authorId: post.authorId,
                );
              },
            ),
          ],
        ),
      ],
      builder: (context, controller, _) => FHeaderAction(
        key: const Key('post-more'),
        icon: const Icon(FLucideIcons.ellipsis),
        semanticsLabel: '更多操作',
        onPress: controller.toggle,
      ),
    );
  }
}
