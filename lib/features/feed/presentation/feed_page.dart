import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../application/feed_notifier.dart';
import 'widgets/post_card.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const _tabs = [
    _TabInfo('推荐', 3),
    _TabInfo('关注', -1),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: theme.colorScheme.surfaceContainerLowest,
            child: TabBar(
              controller: _tabController,
              indicator: const BoxDecoration(),
              dividerColor: Colors.transparent,
              tabs: _tabs.asMap().entries.map((entry) {
                final index = entry.key;
                final label = entry.value.label;
                return _AnimatedTab(
                  label: label,
                  index: index,
                  controller: _tabController,
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _FeedContent(sortBy: t.sortBy)).toList(),
      ),
    );
  }
}

class _AnimatedTab extends StatelessWidget {
  final String label;
  final int index;
  final TabController controller;

  const _AnimatedTab({
    required this.label,
    required this.index,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final unselectedColor = Theme.of(context).colorScheme.outline;

    return AnimatedBuilder(
      animation: controller.animation!,
      builder: (context, child) {
        final value = controller.animation!.value;
        final selectedness = 1.0 - (value - index).abs().clamp(0.0, 1.0);
        final scale = 0.9 + 0.15 * selectedness;
        final color = Color.lerp(unselectedColor, primaryColor, selectedness)!;

        return Transform.scale(
          scale: scale,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selectedness > 0.5 ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabInfo {
  final String label;
  final int sortBy;
  const _TabInfo(this.label, this.sortBy);
}

class _FeedContent extends ConsumerStatefulWidget {
  final int sortBy;
  const _FeedContent({required this.sortBy});

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(feedNotifierProvider(widget.sortBy).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedNotifierProvider(widget.sortBy));

    if (widget.sortBy == -1) {
      return const EmptyView(message: '关注流功能开发中');
    }

    if (feedState.isLoading && feedState.posts.isEmpty) {
      return const PostCardSkeletonList();
    }

    if (feedState.error != null && feedState.posts.isEmpty) {
      return ErrorView(
        message: feedState.error!,
        onRetry: () =>
            ref.read(feedNotifierProvider(widget.sortBy).notifier).refresh(),
      );
    }

    if (feedState.posts.isEmpty) {
      return const EmptyView(message: '还没有帖子，快来发布第一篇吧');
    }

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(feedNotifierProvider(widget.sortBy).notifier).refresh(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: feedState.posts.length + (feedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= feedState.posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return PostCard(post: feedState.posts[index]);
        },
      ),
    );
  }
}
