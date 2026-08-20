import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/api/json_int64.dart';
import '../../../../core/widgets/app_tag_badge.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../behavior/application/behavior_tracker.dart';
import '../../data/feed_models.dart';
import '../../../interaction/data/interaction_repository.dart';
import '../../../../sdk/data/gateway.dart';

final postCardInteractionRepositoryProvider = Provider<InteractionRepository>(
  (ref) => InteractionRepository(),
);

class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final FeedRecommendationContext? recommendationContext;
  final bool trackingActive;

  const PostCard({
    super.key,
    required this.post,
    this.recommendationContext,
    this.trackingActive = true,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard>
    with WidgetsBindingObserver {
  static const _visibilityThreshold = 0.5;
  static const _exposureThreshold = Duration(seconds: 1);
  static const _visibilityPollInterval = Duration(milliseconds: 100);

  late bool _isLiked;
  bool _isLikePending = false;
  late int _likeCount;
  Timer? _visibilityPoller;
  Timer? _exposureTimer;
  DateTime? _visibleSince;
  DateTime? _dwellStartedAt;
  bool _exposureReported = false;

  PostItem get post => widget.post;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiked = post.isLiked;
    _likeCount = post.likeCount.toInt();
    _startVisibilityTracking();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final contextChanged =
        oldWidget.post.id != post.id ||
        oldWidget.recommendationContext?.requestId !=
            widget.recommendationContext?.requestId;
    if (contextChanged || oldWidget.trackingActive && !widget.trackingActive) {
      _endVisibilitySession(
        postId: oldWidget.post.id,
        recommendationContext: oldWidget.recommendationContext,
      );
    }
    if (contextChanged) {
      _exposureTimer?.cancel();
      _exposureTimer = null;
      _visibleSince = null;
      _dwellStartedAt = null;
      _exposureReported = false;
    }
    if (widget.recommendationContext != null && _visibilityPoller == null) {
      _startVisibilityTracking();
    }
    if (oldWidget.post.id != post.id) {
      _isLiked = post.isLiked;
      _isLikePending = false;
      _likeCount = post.likeCount.toInt();
    } else if (!_isLikePending &&
        (oldWidget.post.isLiked != post.isLiked ||
            oldWidget.post.likeCount != post.likeCount)) {
      _isLiked = post.isLiked;
      _likeCount = post.likeCount.toInt();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _evaluateVisibility();
      return;
    }
    _endVisibilitySession();
  }

  @override
  void dispose() {
    _visibilityPoller?.cancel();
    _exposureTimer?.cancel();
    _endVisibilitySession();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _toggleLike() async {
    if (_isLikePending) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }

    final wasLiked = _isLiked;
    setState(() {
      _isLiked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
      _isLikePending = true;
    });

    try {
      final repo = ref.read(postCardInteractionRepositoryProvider);
      if (wasLiked) {
        await repo.unlikeTarget(post.id, 1);
      } else {
        await repo.likeTarget(post.id, 1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLiked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _isLikePending = false);
      }
    }
  }

  void _openPost() {
    final trackingContext = widget.recommendationContext;
    if (trackingContext != null) {
      _trackSafely(
        () => ref
            .read(behaviorTrackerProvider)
            .trackClick(post.id, trackingContext),
      );
    }
    _endVisibilitySession();
    context.push('/post/${jsonInt64Id(post.id)}');
  }

  void _startVisibilityTracking() {
    if (widget.recommendationContext == null || _visibilityPoller != null) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.recommendationContext == null) return;
      _evaluateVisibility();
      _visibilityPoller = Timer.periodic(
        _visibilityPollInterval,
        (_) => _evaluateVisibility(),
      );
    });
  }

  void _evaluateVisibility() {
    final trackingContext = widget.recommendationContext;
    if (!mounted || trackingContext == null || !widget.trackingActive) {
      _endVisibilitySession();
      return;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      _endVisibilitySession();
      return;
    }

    final cardRect =
        renderObject.localToGlobal(Offset.zero) & renderObject.size;
    final viewportRect = Offset.zero & MediaQuery.sizeOf(context);
    final intersection = cardRect.intersect(viewportRect);
    final visibleArea = intersection.isEmpty
        ? 0.0
        : intersection.width * intersection.height;
    final cardArea = cardRect.width * cardRect.height;
    final visibleFraction = cardArea <= 0 ? 0.0 : visibleArea / cardArea;
    if (visibleFraction < _visibilityThreshold) {
      _endVisibilitySession();
      return;
    }

    final now = DateTime.now();
    _visibleSince ??= now;
    _dwellStartedAt ??= now;
    if (_exposureReported || _exposureTimer != null) return;
    _exposureTimer = Timer(_exposureThreshold, () {
      _exposureTimer = null;
      if (!mounted ||
          !widget.trackingActive ||
          _visibleSince == null ||
          widget.recommendationContext == null) {
        return;
      }
      _exposureReported = true;
      _trackSafely(
        () => ref
            .read(behaviorTrackerProvider)
            .trackExposure(post.id, trackingContext),
      );
    });
  }

  void _endVisibilitySession({
    Object? postId,
    FeedRecommendationContext? recommendationContext,
  }) {
    _exposureTimer?.cancel();
    _exposureTimer = null;
    _visibleSince = null;
    final startedAt = _dwellStartedAt;
    _dwellStartedAt = null;
    final trackingContext =
        recommendationContext ?? widget.recommendationContext;
    if (!_exposureReported || startedAt == null || trackingContext == null) {
      return;
    }
    final duration = DateTime.now().difference(startedAt);
    _trackSafely(
      () => ref
          .read(behaviorTrackerProvider)
          .trackDwell(postId ?? post.id, trackingContext, duration),
    );
  }

  void _trackSafely(Future<void> Function() track) {
    unawaited(() async {
      try {
        await track();
      } catch (_) {
        // Analytics failures must not interrupt the user action.
      }
    }());
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final typography = theme.typography;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: FCard(
        builder: (context, style, _) => FTappable(
          onPress: _openPost,
          child: Padding(
            padding: style.padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 作者信息行（更紧凑）
                Row(
                  children: [
                    FTappable(
                      onPress: () =>
                          context.push('/user/${jsonInt64Id(post.authorId)}'),
                      child: CachedAvatar(
                        url: post.authorAvatar,
                        name: post.authorName,
                        radius: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: typography.body.sm.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt),
                      style: typography.body.xs.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // 标题
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    style: typography.body.md.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                // 内容摘要
                if (post.content.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      post.content,
                      style: typography.body.sm.copyWith(
                        color: colors.mutedForeground,
                      ),
                      maxLines: post.title.isNotEmpty ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // 图片展示（首张占满宽度）
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _buildImagePreview(context),
                ],
                // 标签
                if (post.tags.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: post.tags
                        .map((tag) => AppTagBadge(label: tag))
                        .toList(),
                  ),
                ],
                // 底部统计
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statItem(
                      context,
                      FLucideIcons.thumbsUp,
                      _likeCount,
                      key: ValueKey('post-like-${jsonInt64Id(post.id)}'),
                      active: _isLiked,
                      onPress: _toggleLike,
                      semanticsLabel: _isLiked
                          ? '取消点赞，当前 $_likeCount 赞'
                          : '点赞，当前 $_likeCount 赞',
                    ),
                    const SizedBox(width: 24),
                    _statItem(
                      context,
                      FLucideIcons.messageCircle,
                      post.commentCount.toInt(),
                    ),
                    const Spacer(),
                    _statItem(
                      context,
                      FLucideIcons.eye,
                      post.viewCount.toInt(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    final colors = context.theme.colors;
    final firstImage = post.images.first;
    final hasMore = post.images.length > 1;

    return ClipRRect(
      borderRadius: context.theme.style.borderRadius.md,
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: firstImage,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(
              width: double.infinity,
              height: 180,
              color: colors.secondary,
            ),
            errorWidget: (_, _, _) => Container(
              width: double.infinity,
              height: 180,
              color: colors.secondary,
              child: Icon(FLucideIcons.image, color: colors.mutedForeground),
            ),
          ),
          if (hasMore)
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x8A000000),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+${post.images.length - 1}',
                  style: const TextStyle(
                    color: Color(0xFFFFFFFF),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statItem(
    BuildContext context,
    IconData icon,
    int count, {
    Key? key,
    bool active = false,
    VoidCallback? onPress,
    String? semanticsLabel,
  }) {
    final theme = context.theme;
    final color = active ? theme.colors.primary : theme.colors.mutedForeground;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            count > 999 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: theme.typography.body.xs.copyWith(color: color),
          ),
        ],
      ),
    );

    if (onPress == null) return content;
    return FTappable(
      key: key,
      onPress: onPress,
      semanticsLabel: semanticsLabel,
      child: content,
    );
  }

  String _formatTime(num timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp.toInt() * 1000);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${date.month}-${date.day}';
  }
}
