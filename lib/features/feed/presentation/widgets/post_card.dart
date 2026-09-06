import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/api/json_int64.dart';
import '../../../../core/formatters/time_formatter.dart';
import '../../../../core/widgets/app_tag_badge.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../../../core/theme/app_theme.dart';
import 'post_media_preview.dart';
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

  late bool _isLiked;
  bool _isLikePending = false;
  late int _likeCount;
  Timer? _exposureTimer;
  DateTime? _visibleSince;
  DateTime? _dwellStartedAt;
  bool _exposureReported = false;
  double _lastVisibleFraction = 0;

  PostItem get post => widget.post;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiked = post.isLiked;
    _likeCount = post.likeCount.toInt();
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // id 为 Object（int64 防精度），比较前必须经 jsonInt64Id 归一。
    final postIdChanged =
        jsonInt64Id(oldWidget.post.id) != jsonInt64Id(post.id);
    final contextChanged =
        postIdChanged ||
        oldWidget.recommendationContext?.requestId !=
            widget.recommendationContext?.requestId;
    if (contextChanged || oldWidget.trackingActive && !widget.trackingActive) {
      _endVisibilitySession(
        postId: oldWidget.post.id,
        recommendationContext: oldWidget.recommendationContext,
      );
    }
    if (!oldWidget.trackingActive && widget.trackingActive) {
      _restartVisibilityIfNeeded();
    }
    if (contextChanged) {
      _exposureTimer?.cancel();
      _exposureTimer = null;
      _visibleSince = null;
      _dwellStartedAt = null;
      _exposureReported = false;
    }
    if (postIdChanged) {
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
    if (state != AppLifecycleState.resumed) {
      _endVisibilitySession();
      return;
    }
    _restartVisibilityIfNeeded();
  }

  @override
  void dispose() {
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

  /// 由 [VisibilityDetector] 在布局变化时回调，取代原先每卡 100ms 的
  /// Timer.periodic 几何轮询。
  void _onVisibilityChanged(VisibilityInfo info) {
    _lastVisibleFraction = info.visibleFraction;
    final trackingContext = widget.recommendationContext;
    if (!mounted || trackingContext == null || !widget.trackingActive) {
      return;
    }
    if (info.visibleFraction < _visibilityThreshold) {
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

  void _restartVisibilityIfNeeded() {
    if (!mounted ||
        !widget.trackingActive ||
        widget.recommendationContext == null ||
        _lastVisibleFraction < _visibilityThreshold) {
      return;
    }
    final now = DateTime.now();
    _visibleSince ??= now;
    _dwellStartedAt ??= now;
    if (_exposureReported || _exposureTimer != null) return;
    final trackingContext = widget.recommendationContext!;
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

    return VisibilityDetector(
      key: Key(
        'post-exposure-${jsonInt64Id(post.id)}-'
        '${widget.recommendationContext?.requestId ?? '-'}',
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.muted, width: 6)),
        ),
        child: FTappable(
          onPress: _openPost,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              12,
              AppTheme.pageInset,
              14,
            ),
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
                        radius: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        post.authorName,
                        style: typography.body.sm.copyWith(
                          color: colors.mutedForeground,
                        ),
                      ),
                    ),
                    Text(
                      formatRelativeTime(post.createdAt),
                      style: typography.body.xs.copyWith(
                        color: colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 标题
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    style: typography.body.md.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
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
                      style: typography.body.md.copyWith(
                        color: colors.foreground,
                      ),
                      maxLines: post.title.isNotEmpty ? 2 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // 图片展示（首张占满宽度）
                if (post.images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  PostMediaPreview(images: post.images),
                ],
                // 底部统计
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: post.tags
                            .map((tag) => AppTagBadge(label: tag))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _statItem(
                      context,
                      FLucideIcons.messageCircle,
                      post.commentCount.toInt(),
                    ),
                    const SizedBox(width: 16),
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
                  ],
                ),
              ],
            ),
          ),
        ),
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
}
