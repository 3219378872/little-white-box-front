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
import '../../../interaction/application/interaction_notifier.dart';
import '../../../../sdk/data/gateway.dart';
import '../../../../core/router/app_routes.dart';

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
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    final id = jsonInt64Id(post.id);
    final interaction = ref.read(interactionNotifierProvider(id));
    final currentlyLiked = interaction.optimisticIsLiked ?? post.isLiked;
    try {
      await ref
          .read(interactionNotifierProvider(id).notifier)
          .toggleLikeTarget(targetId: post.id, currentlyLiked: currentlyLiked);
    } catch (e) {
      if (!mounted) return;
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
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
    context.push(AppRoutes.postDetail(post.id));
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
    final interaction = ref.watch(
      interactionNotifierProvider(jsonInt64Id(post.id)),
    );
    final isLiked = interaction.optimisticIsLiked ?? post.isLiked;
    final likeCount = interaction.likeCountFor(
      count: post.likeCount.toInt(),
      isLiked: post.isLiked,
    );

    return VisibilityDetector(
      key: Key(
        'post-exposure-${jsonInt64Id(post.id)}-'
        '${widget.recommendationContext?.requestId ?? '-'}',
      ),
      onVisibilityChanged: _onVisibilityChanged,
      child: FTappable(
        onPress: _openPost,
        builder: (context, variants, child) => DecoratedBox(
          decoration: BoxDecoration(
            color:
                variants.contains(FTappableVariant.hovered) ||
                    variants.contains(FTappableVariant.pressed)
                ? colors.muted
                : colors.background,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: child,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            AppTheme.space4,
            AppTheme.pageInset,
            AppTheme.space2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FTappable(
                    onPress: () =>
                        context.push(AppRoutes.userProfile(post.authorId)),
                    semanticsLabel: '查看作者 ${post.authorName}',
                    child: CachedAvatar(
                      url: post.authorAvatar,
                      name: post.authorName,
                      radius: 14,
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  Flexible(
                    child: Text(
                      post.authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: typography.body.sm.copyWith(
                        color: colors.foreground,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    '  ·  ${formatRelativeTime(post.createdAt)}',
                    style: typography.body.xs.copyWith(
                      color: colors.mutedForeground,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              if (post.title.isNotEmpty)
                Text(
                  post.title,
                  style: typography.body.lg.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              if (post.content.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppTheme.space1),
                  child: Text(
                    post.content,
                    style: typography.body.sm.copyWith(
                      color: colors.secondaryForeground,
                      height: 1.6,
                    ),
                    maxLines: post.title.isNotEmpty ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space3),
                PostMediaPreview(images: post.images),
              ],
              const SizedBox(height: AppTheme.space2),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppTheme.space1,
                      runSpacing: AppTheme.space1,
                      children: post.tags
                          .map((tag) => AppTagBadge(label: tag))
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: AppTheme.space2),
                  _statItem(
                    context,
                    FLucideIcons.messageCircle,
                    post.commentCount.toInt(),
                  ),
                  _statItem(
                    context,
                    FLucideIcons.thumbsUp,
                    likeCount,
                    key: ValueKey('post-like-${jsonInt64Id(post.id)}'),
                    active: isLiked,
                    onPress: _toggleLike,
                    semanticsLabel: isLiked
                        ? '取消点赞，当前 $likeCount 赞'
                        : '点赞，当前 $likeCount 赞',
                  ),
                ],
              ),
            ],
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
    // Zero counts are noise; the icon alone still names the action.
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 44, minHeight: 36),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.space2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            if (count > 0) ...[
              const SizedBox(width: AppTheme.space1),
              Text(
                count > 999
                    ? '${(count / 1000).toStringAsFixed(1)}k'
                    : '$count',
                style: theme.typography.body.xs.copyWith(color: color),
              ),
            ],
          ],
        ),
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
