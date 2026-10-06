import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../../../core/widgets/loading_view.dart';
import '../../behavior/application/behavior_tracker.dart';
import '../../behavior/data/behavior_event.dart';
import '../../../core/widgets/forui_pull_to_refresh.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/feed_notifier.dart';
import '../data/feed_models.dart';
import 'widgets/feed_side_rail.dart';
import 'widgets/post_card.dart';
import 'widgets/sponsored_ad_card.dart';
import '../../ads/application/ads_dependencies.dart';
import '../../../core/router/app_routes.dart';

/// 首页信息流：「关注 / 推荐」两个标签页（默认推荐），宽屏时右侧附加侧栏。
class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

// 记录当前标签，只让可见标签的列表触发续翻与曝光追踪。
class _FeedPageState extends ConsumerState<FeedPage> {
  int _selectedTab = 1;

  // 可用宽度容得下信息流列、间距与侧栏时才显示侧栏。
  static const _railBreakpoint =
      AppTheme.feedColumnWidth + AppTheme.space6 + AppTheme.sideRailWidth;

  @override
  Widget build(BuildContext context) {
    // 窄于 lg 断点（没有桌面侧边栏）时，在标签栏右侧补搜索与消息入口。
    final showTools =
        MediaQuery.sizeOf(context).width < context.theme.breakpoints.lg;
    final theme = context.theme;
    final tabs = Stack(
      children: [
        // 标签栏与两个信息流列表；右侧为快捷入口预留空间。
        FTabs(
          scrollable: true,
          style: FTabsStyleDelta.delta(
            padding: EdgeInsetsGeometryDelta.value(
              EdgeInsets.only(
                left: AppTheme.space1,
                right: showTools ? 100 : 0,
              ),
            ),
            minHeight: 52,
            labelTextStyle: FVariants.from(
              theme.typography.body.lg.copyWith(
                color: theme.colors.mutedForeground,
              ),
              variants: {
                [FTabVariant.selected]: TextStyleDelta.delta(
                  fontWeight: FontWeight.w700,
                  color: theme.colors.foreground,
                ),
              },
            ),
          ),
          control: FTabControl.managed(
            initial: 1,
            onChange: (index) => setState(() => _selectedTab = index),
          ),
          expands: true,
          contentPhysics: const BouncingScrollPhysics(),
          children: [
            FTabEntry(
              label: const Text('关注'),
              child: _FeedContent(
                kind: FeedKind.follow,
                active: _selectedTab == 0,
              ),
            ),
            FTabEntry(
              label: const Text('推荐'),
              child: _FeedContent(
                kind: FeedKind.recommend,
                active: _selectedTab == 1,
              ),
            ),
          ],
        ),
        // Hairline under the sticky tab bar separates it from the list.
        Positioned(
          top: 52,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: SizedBox(
              height: 1,
              child: ColoredBox(color: theme.colors.border),
            ),
          ),
        ),
        // 窄屏快捷入口：搜索与消息。
        if (showTools)
          Positioned(
            top: 4,
            right: 8,
            child: Row(
              children: [
                AppIconButton(
                  icon: FLucideIcons.search,
                  label: '搜索',
                  onPress: () => context.go(AppRoutes.search),
                ),
                AppIconButton(
                  icon: FLucideIcons.messageSquare,
                  label: '消息',
                  onPress: () => context.go(AppRoutes.messages),
                ),
              ],
            ),
          ),
      ],
    );
    // 宽屏：信息流列 + 侧栏并排；否则只有信息流。
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < _railBreakpoint) return tabs;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: AppTheme.feedColumnWidth, child: tabs),
            const SizedBox(width: AppTheme.space6),
            const SizedBox(
              width: AppTheme.sideRailWidth,
              child: FeedSideRail(),
            ),
          ],
        );
      },
    );
  }
}

// 单个信息流列表：按加载状态切换骨架、错误、空态与列表，并处理续翻与广告操作。
class _FeedContent extends ConsumerStatefulWidget {
  final FeedKind kind;
  // 是否为当前可见标签；不可见时不续翻、不上报曝光。
  final bool active;

  const _FeedContent({required this.kind, required this.active});

  @override
  ConsumerState<_FeedContent> createState() => _FeedContentState();
}

// 根据 feed notifier 状态选择展示形态，并把滚动、广告隐藏与举报转成 notifier 调用。
class _FeedContentState extends ConsumerState<_FeedContent> {
  // 距底部不足该距离时续翻。
  static const _loadMoreExtent = 200.0;

  @override
  Widget build(BuildContext context) {
    // 关注流需要登录：身份恢复中显示加载，未登录给登录引导。
    if (widget.kind == FeedKind.follow) {
      final auth = ref.watch(authNotifierProvider);
      if (auth.isLoading) {
        return const LoadingView();
      }
      if (!auth.isAuthenticated) return const _FollowLoginRequired();
    }

    final feedState = ref.watch(feedNotifierProvider(widget.kind));
    final notifier = ref.read(feedNotifierProvider(widget.kind).notifier);

    // 首屏失败：整体错误态。
    if (feedState.error != null && feedState.entries.isEmpty) {
      return ErrorView(message: feedState.error!, onRetry: notifier.refresh);
    }

    // 首屏加载：骨架屏。
    if (feedState.isLoading && feedState.entries.isEmpty) {
      return const PostCardSkeletonList();
    }

    // 首屏翻到上限仍无条目但还有更多：保持骨架并在下一帧自动续翻。
    if (feedState.entries.isEmpty &&
        feedState.hasMore &&
        feedState.error == null &&
        (feedState.isLoadingMore || feedState.requestId.isNotEmpty)) {
      if (!feedState.isLoadingMore) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !widget.active) return;
          ref.read(feedNotifierProvider(widget.kind).notifier).loadMore();
        });
      }
      return const PostCardSkeletonList();
    }

    // 确实没有内容：可下拉刷新的空态。
    if (feedState.entries.isEmpty) {
      return ForuiPullToRefresh(
        onRefresh: notifier.refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyView(
                message: widget.kind == FeedKind.follow
                    ? '还没有关注动态'
                    : '还没有帖子，快来发布第一篇吧',
              ),
            ),
          ],
        ),
      );
    }

    // 有内容：帖子与广告混排列表，尾部按需追加状态行。
    final showFooter = _showFeedFooter(feedState);
    final rows = feedState.rows;
    return ForuiPullToRefresh(
      onRefresh: notifier.refresh,
      // 同时监听尺寸变化与滚动：内容不足一屏时也能触发续翻。
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleScrollMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: ListView.builder(
            key: PageStorageKey('feed-${widget.kind.name}'),
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: rows.length + (showFooter ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return _feedFooter(feedState, notifier);
              }
              return _feedRow(rows[index]);
            },
          ),
        ),
      ),
    );
  }

  // 只处理列表自身（depth 0）的滚动通知。
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _maybeLoadMore(notification.metrics);
    return false;
  }

  // 列表尺寸变化（如追加内容后仍不满一屏）时同样检查是否需要续翻。
  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    _maybeLoadMore(notification.metrics);
    return false;
  }

  // 接近底部且没有未处理的失败时，下一帧续翻；帧回调里再次确认仍可见、仍无失败。
  void _maybeLoadMore(ScrollMetrics metrics) {
    if (!widget.active || metrics.axis != Axis.vertical) return;
    if (metrics.extentAfter > _loadMoreExtent) return;
    final feedState = ref.read(feedNotifierProvider(widget.kind));
    if (feedState.error != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.active) return;
      final latest = ref.read(feedNotifierProvider(widget.kind));
      if (latest.error != null) return;
      ref.read(feedNotifierProvider(widget.kind).notifier).loadMore();
    });
  }

  // 续翻中、已到底或已有内容但加载失败时显示尾部行。
  bool _showFeedFooter(FeedState state) {
    return state.isLoadingMore ||
        !state.hasMore ||
        (state.error != null && state.entries.isNotEmpty);
  }

  // 信息流尾部：已有内容时的失败按失败类型选择续翻或整体刷新，到底时提示结束。
  Widget _feedFooter(FeedState state, FeedNotifier notifier) {
    return LoadMoreFooter(
      isLoading: state.isLoadingMore,
      error: state.entries.isNotEmpty ? state.error : null,
      onRetry: state.loadMoreFailed ? notifier.loadMore : notifier.refresh,
      showEnd: true,
    );
  }

  // 按行类型渲染帖子卡片或广告卡片；key 带请求 ID，换快照后重建以重新追踪曝光。
  Widget _feedRow(FeedRow row) {
    return switch (row) {
      FeedPostRow(:final entry) => PostCard(
        key: ValueKey(
          '${widget.kind.name}-${entry.context.requestId}-${entry.post.id}',
        ),
        post: entry.post,
        recommendationContext: entry.context,
        trackingActive: widget.active,
      ),
      FeedAdRow(:final slot) => SponsoredAdCard(
        key: ValueKey(slot.key),
        slot: slot,
        trackingActive: widget.active,
        onHide: () => _hideAd(slot),
        onReport: (reason) => _reportAd(slot, reason),
      ),
    };
  }

  /// 举报后服务端已对本人隐藏该广告，因此本地同样先移除；失败时按原位置恢复（FX-101）。
  Future<void> _reportAd(SponsoredSlot slot, String reason) async {
    try {
      await ref
          .read(feedNotifierProvider(widget.kind).notifier)
          .hideAd(
            slot.ad.adId,
            () =>
                ref.read(adsRepositoryProvider).reportAd(slot.ad.adId, reason),
          );
    } on AdHideFailure catch (failure) {
      if (!mounted) return;
      showAppError(context, failure.restored ? '举报失败，广告已恢复' : '举报失败，请稍后重试');
      return;
    }
    if (mounted) showAppSuccess(context, '已举报，感谢反馈');
  }

  /// 隐藏成功后才上报 `hide` 行为，失败的隐藏不计入广告统计（FX-101、FX-104）。
  Future<void> _hideAd(SponsoredSlot slot) async {
    try {
      await ref
          .read(feedNotifierProvider(widget.kind).notifier)
          .hideAd(
            slot.ad.adId,
            () => ref.read(adsRepositoryProvider).hideAd(slot.ad.adId),
          );
    } on AdHideFailure catch (failure) {
      if (!mounted) return;
      showAppError(context, failure.restored ? '隐藏失败，广告已恢复' : '隐藏失败，请稍后重试');
      return;
    }
    // 行为上报异步执行，不阻塞界面。
    unawaited(() async {
      try {
        await ref
            .read(behaviorTrackerProvider)
            .trackHide(
              slot.ad.adId,
              slot.context,
              targetType: behaviorTargetAd,
            );
      } catch (_) {
        // Analytics failures must not interrupt the user action.
      }
    }());
  }
}

// 关注标签在未登录时的占位：说明与登录按钮。
class _FollowLoginRequired extends StatelessWidget {
  const _FollowLoginRequired();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FLucideIcons.userRoundCheck,
              size: 48,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text('登录后查看关注动态', style: theme.typography.body.lg),
            const SizedBox(height: 16),
            FButton(
              onPress: () => context.push(AppRoutes.login),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
