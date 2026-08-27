import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/forui_pull_to_refresh.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/feed_notifier.dart';
import '../data/feed_models.dart';
import 'widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return FTabs(
      control: FTabControl.managed(
        onChange: (index) => setState(() => _selectedTab = index),
      ),
      expands: true,
      contentPhysics: const BouncingScrollPhysics(),
      children: [
        FTabEntry(
          label: const Text('推荐'),
          child: _FeedContent(
            kind: FeedKind.recommend,
            active: _selectedTab == 0,
          ),
        ),
        FTabEntry(
          label: const Text('关注'),
          child: _FeedContent(kind: FeedKind.follow, active: _selectedTab == 1),
        ),
      ],
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
        return const Center(child: FCircularProgress());
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

    final isDesktop =
        MediaQuery.sizeOf(context).width >= context.theme.breakpoints.lg;
    final showFooter = _showFeedFooter(feedState);
    return ForuiPullToRefresh(
      onRefresh: notifier.refresh,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleScrollMetrics,
        child: NotificationListener<ScrollNotification>(
          onNotification: _handleScrollNotification,
          child: isDesktop
              ? ListView.builder(
                  key: PageStorageKey('feed-grid-${widget.kind.name}'),
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
                  itemCount:
                      (feedState.entries.length + 1) ~/ 2 + (showFooter ? 1 : 0),
                  itemBuilder: (context, row) {
                    final start = row * 2;
                    if (start >= feedState.entries.length) {
                      return _feedFooter(feedState, notifier);
                    }
                    final left = _feedItem(feedState, start);
                    final right = start + 1 < feedState.entries.length
                        ? _feedItem(feedState, start + 1)
                        : const SizedBox.shrink();
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: left),
                        Expanded(child: right),
                      ],
                    );
                  },
                )
              : ListView.builder(
                  key: PageStorageKey('feed-${widget.kind.name}'),
                  primary: false,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 80),
                  itemCount: feedState.entries.length + (showFooter ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= feedState.entries.length) {
                      return _feedFooter(feedState, notifier);
                    }
                    return _feedItem(feedState, index);
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

  Widget _feedFooter(FeedState state, FeedNotifier notifier) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: FCircularProgress()),
      );
    }
    if (state.error != null && state.entries.isNotEmpty) {
      final theme = context.theme;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Text(
              state.error!,
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            FButton(
              variant: FButtonVariant.secondary,
              onPress: state.loadMoreFailed
                  ? notifier.loadMore
                  : notifier.refresh,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          '— 没有更多了 —',
          style: TextStyle(
            color: context.theme.colors.mutedForeground,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _feedItem(FeedState feedState, int index) {
    final entry = feedState.entries[index];
    return PostCard(
      key: ValueKey(
        '${widget.kind.name}-${entry.context.requestId}-${entry.post.id}',
      ),
      post: entry.post,
      recommendationContext: entry.context,
      trackingActive: widget.active,
    );
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
