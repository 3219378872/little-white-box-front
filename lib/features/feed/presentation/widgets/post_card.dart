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

/// 信息流与个人页共用的帖子卡片：作者行、标题摘要、配图、标签与评论/点赞计数。
///
/// 带 [recommendationContext] 时额外上报曝光、点击与停留行为；个人页等场景不传则不追踪。
class PostCard extends ConsumerStatefulWidget {
  final PostItem post;
  final FeedRecommendationContext? recommendationContext;

  /// 所在列表是否可见；不可见（如切到另一标签）时暂停追踪。
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

// 维护曝光计时与停留会话，并监听前后台切换以暂停/恢复追踪。
class _PostCardState extends ConsumerState<PostCard>
    with WidgetsBindingObserver {
  // 视为可见的最小可见比例与曝光所需的连续可见时长。
  static const _visibilityThreshold = 0.5;
  static const _exposureThreshold = Duration(seconds: 1);

  // 曝光计时器、本次可见开始时间、停留计时起点与「本卡片已曝光」标记。
  Timer? _exposureTimer;
  DateTime? _visibleSince;
  DateTime? _dwellStartedAt;
  bool _exposureReported = false;
  // 最近一次可见比例，恢复追踪时据此判断是否立即重新计时。
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
    // 换了帖子/快照或追踪被关闭：以旧参数结束上一段可见会话。
    if (contextChanged || oldWidget.trackingActive && !widget.trackingActive) {
      _endVisibilitySession(
        postId: oldWidget.post.id,
        recommendationContext: oldWidget.recommendationContext,
      );
    }
    if (!oldWidget.trackingActive && widget.trackingActive) {
      _restartVisibilityIfNeeded();
    }
    // 新帖子或新快照重新计曝光。
    if (contextChanged) {
      _exposureTimer?.cancel();
      _exposureTimer = null;
      _visibleSince = null;
      _dwellStartedAt = null;
      _exposureReported = false;
    }
  }

  // 切到后台结束可见会话，回到前台按最近可见比例恢复。
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

  // 点赞：匿名先去登录；以乐观态为当前值切换，失败由 interaction notifier 回滚并在此提示。
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

  // 打开详情：先上报点击并结束可见会话，再跳转。
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

  // 可见比例变化回调（由 [VisibilityDetector] 在布局变化时触发）：可见过半开始计停留，
  // 连续 1 秒上报一次曝光；低于阈值时结束本次可见会话（已曝光时上报停留）。
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

  // 恢复追踪（回到前台或标签重新可见）：若卡片仍足够可见，重新开始停留与曝光计时。
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

  // 结束一段可见会话：取消曝光计时；只有曝光过的会话才上报停留时长。
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

  // 行为上报异步执行且吞掉异常，不打断用户操作。
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

    // 可见性检测包住整张卡片；key 带帖子与请求 ID，换快照时作为新目标追踪。
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
              // 作者行：头像（进入主页）、昵称与发布时间。
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
              // 标题与正文摘要：有标题时正文最多两行，否则三行。
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
              // 配图预览
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space3),
                PostMediaPreview(images: post.images),
              ],
              // 底栏：标签与评论/点赞计数（点赞可点）。
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

  // 计数项：图标加计数（超过 999 显示为 k），传入 onPress 时可点击。
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
