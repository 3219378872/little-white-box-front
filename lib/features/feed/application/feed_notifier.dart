import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../sdk/data/gateway.dart';
import '../data/post_list_repository.dart';

class FeedState {
  final List<PostItem> posts;
  final int currentPage;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const FeedState({
    this.posts = const [],
    this.currentPage = 1,
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  FeedState copyWith({
    List<PostItem>? posts,
    int? currentPage,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final PostListRepository _repo;
  final int sortBy;
  static const _pageSize = 20;

  FeedNotifier(this._repo, this.sortBy) : super(const FeedState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final resp =
          await _repo.fetchPosts(page: 1, pageSize: _pageSize, sortBy: sortBy);
      state = FeedState(
        posts: resp.list,
        currentPage: 1,
        hasMore: resp.list.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: friendlyErrorMessage(e));
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final resp = await _repo.fetchPosts(
          page: nextPage, pageSize: _pageSize, sortBy: sortBy);
      state = state.copyWith(
        posts: [...state.posts, ...resp.list],
        currentPage: nextPage,
        hasMore: resp.list.length >= _pageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: friendlyErrorMessage(e));
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

final postListRepoProvider = Provider((ref) => PostListRepository());

/// 按排序类型创建独立的 FeedNotifier
final feedNotifierProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, int>(
  (ref, sortBy) => FeedNotifier(ref.read(postListRepoProvider), sortBy),
);
