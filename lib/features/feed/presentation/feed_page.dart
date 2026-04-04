import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../../../features/auth/application/auth_notifier.dart';
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
    _TabInfo('最新', 1),
    _TabInfo('热门', 2),
    _TabInfo('推荐', 3),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('小白盒'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs.map((t) => Tab(text: t.label)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children:
            _tabs.map((t) => _FeedListView(sortBy: t.sortBy)).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final auth = ref.read(authNotifierProvider);
          if (!auth.isAuthenticated) {
            context.push('/auth/login');
            return;
          }
          context.push('/post/new');
        },
        child: const Icon(Icons.edit),
      ),
    );
  }
}

class _TabInfo {
  final String label;
  final int sortBy;
  const _TabInfo(this.label, this.sortBy);
}

class _FeedListView extends ConsumerStatefulWidget {
  final int sortBy;
  const _FeedListView({required this.sortBy});

  @override
  ConsumerState<_FeedListView> createState() => _FeedListViewState();
}

class _FeedListViewState extends ConsumerState<_FeedListView> {
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
