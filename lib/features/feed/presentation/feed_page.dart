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
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!widget.active || !_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedNotifierProvider(widget.kind).notifier).loadMore();
    }
  }

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

    if (feedState.isLoading && feedState.entries.isEmpty) {
      return const PostCardSkeletonList();
    }

    if (feedState.error != null && feedState.entries.isEmpty) {
      return ErrorView(message: feedState.error!, onRetry: notifier.refresh);
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
    return ForuiPullToRefresh(
      onRefresh: notifier.refresh,
      child: isDesktop
          ? ListView.builder(
              key: PageStorageKey('feed-grid-${widget.kind.name}'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 80),
              itemCount:
                  (feedState.entries.length + 1) ~/ 2 +
                  (feedState.isLoadingMore ? 1 : 0),
              itemBuilder: (context, row) {
                final start = row * 2;
                if (start >= feedState.entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: FCircularProgress()),
                  );
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
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount:
                  feedState.entries.length + (feedState.isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= feedState.entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: FCircularProgress()),
                  );
                }
                return _feedItem(feedState, index);
              },
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
