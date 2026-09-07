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

part 'post_detail_content.dart';
part 'post_detail_comments.dart';
part 'post_detail_actions.dart';

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
          final comments = ref.watch(commentNotifierProvider(widget.postId));

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    // 帖子内容
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
