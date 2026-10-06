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
import '../../ads/data/ads_repository.dart';
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

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  int _selectedTab = 1;

  static const _railBreakpoint =
      AppTheme.feedColumnWidth + AppTheme.space6 + AppTheme.sideRailWidth;

  @override
  Widget build(BuildContext context) {
    final showTools =
        MediaQuery.sizeOf(context).width < context.theme.breakpoints.lg;
    final theme = context.theme;
    final tabs = Stack(
      children: [
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
        if (showTools)
          Positioned(
            top: 4,
            right: 8,
            child: Row(
              children: [
                AppIconButton(
                  icon: FLucideIcons.search,
                  label: '搜索',
                  onPress: () => context.go('/search'),
                ),
                AppIconButton(
                  icon: FLucideIcons.messageSquare,
                  label: '消息',
                  onPress: () => context.go('/messages'),
                ),
              ],
            ),
          ),
      ],
    );
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

class _FeedContent extends ConsumerStatefulWidget {
  final FeedKind kind;
  final bool active;

  const _FeedContent({required this.kind, required this.active});

  @override
  ConsumerState<_FeedContent> createState() => _FeedContentState();
}

class _FeedContentState extends ConsumerState<_FeedContent> {
  static const _loadMoreExtent = 200.0;

  @override
  Widget build(BuildContext context) {
    if (widget.kind == FeedKind.follow) {
      final auth = ref.watch(authNotifierProvider);
      if (auth.isLoading) {
        return const LoadingView();
      }
      if (!auth.isAuthenticated) return const _FollowLoginRequired();
    }

    final feedState = ref.watch(feedNotifierProvider(widget.kind));
    final notifier = ref.read(feedNotifierProvider(widget.kind).notifier);

    if (feedState.error != null && feedState.entries.isEmpty) {
      return ErrorView(message: feedState.error!, onRetry: notifier.refresh);
    }

    if (feedState.isLoading && feedState.entries.isEmpty) {
      return const PostCardSkeletonList();
    }

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

    final showFooter = _showFeedFooter(feedState);
    final rows = feedState.rows;
    return ForuiPullToRefresh(
      onRefresh: notifier.refresh,
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

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    _maybeLoadMore(notification.metrics);
    return false;
  }

  bool _handleScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    _maybeLoadMore(notification.metrics);
    return false;
  }

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
              onPress: () => context.push('/auth/login'),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
