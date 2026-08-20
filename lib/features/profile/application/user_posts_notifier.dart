import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sdk/data/gateway.dart';
import '../data/user_repository.dart';

enum UserPostsListType { posts, favorites }

class UserPostsKey {
  final num userId;
  final UserPostsListType type;
  const UserPostsKey({required this.userId, required this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPostsKey && other.userId == userId && other.type == type);

  @override
  int get hashCode => Object.hash(userId, type);
}

abstract class UserPostsRepository {
  Future<GetPostListResp> fetchUserPosts({
    required num userId,
    required int page,
    required int pageSize,
    int sortBy = 1,
  });

  Future<GetPostListResp> fetchUserFavorites({
    required num userId,
    required int page,
    required int pageSize,
  });
}

class UserPostsState {
  final List<PostItem> items;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  const UserPostsState({
    this.items = const [],
    this.page = 0,
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  UserPostsState copyWith({
    List<PostItem>? items,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) {
    return UserPostsState(
      items: items ?? this.items,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class UserPostsNotifier extends StateNotifier<UserPostsState> {
  final UserPostsRepository repo;
  final UserPostsKey key;
  final int pageSize;
  int _generation = 0;

  UserPostsNotifier({
    required this.repo,
    required this.key,
    this.pageSize = 20,
  }) : super(const UserPostsState());

  Future<GetPostListResp> _fetch(int page) {
    if (key.type == UserPostsListType.posts) {
      return repo.fetchUserPosts(
        userId: key.userId,
        page: page,
        pageSize: pageSize,
      );
    } else {
      return repo.fetchUserFavorites(
        userId: key.userId,
        page: page,
        pageSize: pageSize,
      );
    }
  }

  Future<void> loadFirstPage() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _fetch(1);
      if (generation != _generation) return;
      state = state.copyWith(
        items: resp.list,
        page: 1,
        hasMore: resp.list.length >= pageSize,
        isLoading: false,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoading || state.isRefreshing) return;
    final generation = _generation;
    state = state.copyWith(isLoading: true);
    final nextPage = state.page + 1;
    try {
      final resp = await _fetch(nextPage);
      if (generation != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...resp.list],
        page: nextPage,
        hasMore: resp.list.length >= pageSize,
        isLoading: false,
      );
    } catch (e) {
      if (generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(isRefreshing: true);
    try {
      final resp = await _fetch(1);
      if (generation != _generation) return;
      state = state.copyWith(
        items: resp.list,
        page: 1,
        hasMore: resp.list.length >= pageSize,
        isRefreshing: false,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      if (generation != _generation) return;
      state = state.copyWith(isRefreshing: false);
    }
  }
}

/// Provider.family
final userPostsProvider = StateNotifierProvider.family<
    UserPostsNotifier, UserPostsState, UserPostsKey>(
  (ref, key) {
    final notifier = UserPostsNotifier(
      repo: ref.read(userPostsRepositoryProvider),
      key: key,
    );
    notifier.loadFirstPage();
    return notifier;
  },
);

final userPostsRepositoryProvider = Provider<UserPostsRepository>((ref) {
  return UserRepository();
});
