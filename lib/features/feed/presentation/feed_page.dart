import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/skeleton_loader.dart';
import '../application/feed_notifier.dart';
import 'widgets/post_card.dart';

class FeedPage extends ConsumerWidget {
  const FeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FScaffold(
      childPad: false,
      child: FTabs(
        expands: true,
        contentPhysics: const BouncingScrollPhysics(),
        children: const [
          FTabEntry(label: Text('推荐'), child: _FeedContent(sortBy: 3)),
          FTabEntry(label: Text('关注'), child: _FeedContent(sortBy: -1)),
        ],
      ),
    );
  }
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
