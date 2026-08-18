import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../../comment/data/comment_repository.dart';
import '../../comment/presentation/widgets/comment_input.dart';
import '../../comment/presentation/widgets/comment_item.dart';
import '../../interaction/data/interaction_repository.dart';
import '../data/post_repository.dart';

final _postRepoProvider = Provider((ref) => PostRepository());
final _commentRepoProvider = Provider((ref) => CommentRepository());
final _interactionRepoProvider = Provider((ref) => InteractionRepository());

final _postDetailProvider = FutureProvider.family<GetPostResp, int>((
  ref,
  postId,
) {
  return ref.read(_postRepoProvider).getPostDetail(postId);
});

class PostDetailPage extends ConsumerStatefulWidget {
  final int postId;
  const PostDetailPage({super.key, required this.postId});

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  List<CommentItem> _comments = [];
  bool _isLoadingComments = false;
  int _commentPage = 1;
  bool _hasMoreComments = true;
  int _commentSortBy = 1;
  final ScrollController _scrollCtrl = ScrollController();

  // 乐观更新状态
  bool? _optimisticIsLiked;
  bool? _optimisticIsFavorited;
  int _likeCountDelta = 0;
  int _favoriteCountDelta = 0;

  String? _replyToUser;
  num _replyParentId = 0;
  num _replyUserId = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _loadComments();
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
    if (_scrollCtrl.position.pixels >= threshold &&
        !_isLoadingComments &&
        _hasMoreComments) {
      _commentPage++;
      _loadComments();
    }
  }

  Future<void> _loadComments() async {
    if (_isLoadingComments) return;
    setState(() => _isLoadingComments = true);
    try {
      final resp = await ref
          .read(_commentRepoProvider)
          .fetchComments(
            postId: widget.postId,
            page: _commentPage,
            pageSize: 20,
            sortBy: _commentSortBy,
          );
      setState(() {
        if (_commentPage == 1) {
          _comments = resp.list;
        } else {
          _comments = [..._comments, ...resp.list];
        }
        _hasMoreComments = resp.list.length >= 20;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _toggleLike(GetPostResp post) async {
    final currentlyLiked = _optimisticIsLiked ?? post.isLiked;
    setState(() {
      _optimisticIsLiked = !currentlyLiked;
      _likeCountDelta += currentlyLiked ? -1 : 1;
    });
    try {
      final repo = ref.read(_interactionRepoProvider);
      if (currentlyLiked) {
        await repo.unlikeTarget(widget.postId, 1);
      } else {
        await repo.likeTarget(widget.postId, 1);
      }
    } catch (e) {
      setState(() {
        _optimisticIsLiked = currentlyLiked;
        _likeCountDelta += currentlyLiked ? 1 : -1;
      });
      if (mounted) {
        showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _toggleFavorite(GetPostResp post) async {
    final currentlyFav = _optimisticIsFavorited ?? post.isFavorited;
    setState(() {
      _optimisticIsFavorited = !currentlyFav;
      _favoriteCountDelta += currentlyFav ? -1 : 1;
    });
    try {
      final repo = ref.read(_interactionRepoProvider);
      if (currentlyFav) {
        await repo.unfavoritePost(widget.postId);
      } else {
        await repo.favoritePost(widget.postId);
      }
    } catch (e) {
      setState(() {
        _optimisticIsFavorited = currentlyFav;
        _favoriteCountDelta += currentlyFav ? 1 : -1;
      });
      if (mounted) {
        showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  Future<void> _submitComment(String content) async {
    final auth = ref.read(authNotifierProvider);
    if (!auth.isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    try {
      await ref
          .read(_commentRepoProvider)
          .createNewComment(
            CreateCommentReq(
              postId: widget.postId,
              parentId: _replyParentId,
              replyUserId: _replyUserId,
              content: content,
              idempotencyKey: newIdempotencyKey(),
            ),
          );
      setState(() {
        _replyToUser = null;
        _replyParentId = 0;
        _replyUserId = 0;
        _commentPage = 1;
      });
      _loadComments();
    } catch (e) {
      if (mounted) {
        showAppError(context, '评论失败: ${friendlyErrorMessage(e)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final postAsync = ref.watch(_postDetailProvider(widget.postId));
    final theme = context.theme;

    return FScaffold(
      childPad: false,
      child: postAsync.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(_postDetailProvider(widget.postId)),
        ),
        data: (post) {
          final isLiked = _optimisticIsLiked ?? post.isLiked;
          final isFavorited = _optimisticIsFavorited ?? post.isFavorited;
          final likeCount = post.likeCount.toInt() + _likeCountDelta;
          final favCount = post.favoriteCount.toInt() + _favoriteCountDelta;
          final headerExtent =
              MediaQuery.paddingOf(context).top +
              (context.platformVariant.touch ? 62.0 : 54.0);

          // 按 parentId 分组评论
          final topLevel = _comments.where((c) => c.parentId == 0).toList();
          final repliesMap = <num, List<CommentItem>>{};
          for (final c in _comments.where((c) => c.parentId != 0)) {
            repliesMap.putIfAbsent(c.parentId, () => []).add(c);
          }

          return Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  controller: _scrollCtrl,
                  slivers: [
                    SliverPersistentHeader(
                      floating: true,
                      delegate: _ForuiHeaderDelegate(
                        extent: headerExtent,
                        child: FHeader.nested(
                          title: Text(post.authorName),
                          prefixes: [
                            FHeaderAction.back(
                              onPress: () => context.canPop()
                                  ? context.pop()
                                  : context.go('/feed'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 帖子内容
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 作者
                            FTappable(
                              onPress: () => context.push(
                                '/user/${post.authorId.toInt()}',
                              ),
                              child: Row(
                                children: [
                                  CachedAvatar(
                                    url: post.authorAvatar,
                                    name: post.authorName,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.authorName,
                                        style: theme.typography.body.md
                                            .copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        _formatTime(post.createdAt),
                                        style: theme.typography.body.xs
                                            .copyWith(
                                              color:
                                                  theme.colors.mutedForeground,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // 标题
                            if (post.title.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  post.title,
                                  style: theme.typography.display.sm,
                                ),
                              ),
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
                            // 操作栏
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _actionButton(
                                  icon: FLucideIcons.thumbsUp,
                                  label: '$likeCount',
                                  active: isLiked,
                                  onTap: () => _toggleLike(post),
                                ),
                                _actionButton(
                                  icon: FLucideIcons.bookmark,
                                  label: '$favCount',
                                  active: isFavorited,
                                  onTap: () => _toggleFavorite(post),
                                ),
                                _actionButton(
                                  icon: FLucideIcons.messageCircle,
                                  label: '${post.commentCount}',
                                  onTap: () {},
                                ),
                                _actionButton(
                                  icon: FLucideIcons.eye,
                                  label: '${post.viewCount}',
                                  onTap: () {},
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: FDivider(),
                            ),
                            // 评论区标题
                            Row(
                              children: [
                                Text('评论', style: theme.typography.body.md),
                                const Spacer(),
                                FButton(
                                  size: .xs,
                                  mainAxisSize: MainAxisSize.min,
                                  variant: _commentSortBy == 1
                                      ? FButtonVariant.secondary
                                      : FButtonVariant.ghost,
                                  onPress: () => _selectCommentSort(1),
                                  child: const Text('最新'),
                                ),
                                const SizedBox(width: 4),
                                FButton(
                                  size: .xs,
                                  mainAxisSize: MainAxisSize.min,
                                  variant: _commentSortBy == 2
                                      ? FButtonVariant.secondary
                                      : FButtonVariant.ghost,
                                  onPress: () => _selectCommentSort(2),
                                  child: const Text('最热'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    // 评论列表
                    if (topLevel.isEmpty && !_isLoadingComments)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Center(
                            child: Text(
                              '还没有评论',
                              style: theme.typography.body.sm.copyWith(
                                color: theme.colors.mutedForeground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= topLevel.length) {
                            // tail 位置：优先显示加载中，否则显示"没有更多了"
                            if (_isLoadingComments) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: FCircularProgress()),
                              );
                            }
                            if (!_hasMoreComments && topLevel.isNotEmpty) {
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
                          return CommentItemWidget(
                            comment: comment,
                            replies: repliesMap[comment.id] ?? [],
                            onReply: () {
                              setState(() {
                                _replyToUser = comment.userName;
                                _replyParentId = comment.id;
                                _replyUserId = comment.userId;
                              });
                            },
                          );
                        },
                        childCount:
                            topLevel.length +
                            ((_isLoadingComments ||
                                    (!_hasMoreComments && topLevel.isNotEmpty))
                                ? 1
                                : 0),
                      ),
                    ),
                  ],
                ),
              ),
              CommentInput(replyTo: _replyToUser, onSubmit: _submitComment),
            ],
          );
        },
      ),
    );
  }

  void _selectCommentSort(int value) {
    if (value == _commentSortBy) return;
    setState(() {
      _commentSortBy = value;
      _commentPage = 1;
      _hasMoreComments = true;
      _comments = [];
    });
    _loadComments();
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final theme = context.theme;
    final color = active ? theme.colors.primary : theme.colors.mutedForeground;
    return FTappable(
      onPress: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 4),
            Text(label, style: theme.typography.body.sm.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  String _formatTime(num timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.year}-${date.month}-${date.day}';
  }
}

class _ForuiHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double extent;
  final Widget child;

  const _ForuiHeaderDelegate({required this.extent, required this.child});

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(color: context.theme.colors.background, child: child);
  }

  @override
  bool shouldRebuild(covariant _ForuiHeaderDelegate oldDelegate) {
    return extent != oldDelegate.extent || child != oldDelegate.child;
  }
}
