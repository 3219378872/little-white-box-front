import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../feed/presentation/widgets/post_card.dart';
import '../../application/user_posts_notifier.dart';

class UserPostList extends ConsumerStatefulWidget {
  final num userId;
  final UserPostsListType type;
  const UserPostList({
    super.key,
    required this.userId,
    required this.type,
  });

  @override
  ConsumerState<UserPostList> createState() => _UserPostListState();
}

class _UserPostListState extends ConsumerState<UserPostList> {
  final ScrollController _scrollCtrl = ScrollController();

  UserPostsKey get _key =>
      UserPostsKey(userId: widget.userId, type: widget.type);

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(userPostsProvider(_key).notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userPostsProvider(_key));
    final notifier = ref.read(userPostsProvider(_key).notifier);

    if (state.error != null && state.items.isEmpty) {
      return ErrorView(
        message: state.error.toString(),
        onRetry: () => notifier.loadFirstPage(),
      );
    }

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            widget.type == UserPostsListType.posts ? '还没有发布任何帖子' : '还没有收藏任何帖子',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => notifier.refresh(),
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: state.items.length +
            ((state.isLoading || !state.hasMore) ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= state.items.length) {
            if (state.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  '— 没有更多了 —',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }
          return PostCard(post: state.items[index]);
        },
      ),
    );
  }
}
