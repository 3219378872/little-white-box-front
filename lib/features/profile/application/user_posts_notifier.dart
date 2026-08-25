import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sdk/data/gateway.dart';
import '../data/user_repository.dart';

enum UserPostsListType { posts, favorites }

class UserPostsKey {
  final Object userId;
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
    required Object userId,
    required String cursor,
    required int pageSize,
    int sortBy = 1,
  });

  Future<GetPostListResp> fetchUserFavorites({
    required Object userId,
    required String cursor,
    required int pageSize,
  });
}

class UserPostsState {
  final List<PostItem> items;

  /// 下一页游标；空串表示没有更多（与网关 nextCursor 语义一致）。
  final String cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  const UserPostsState({
    this.items = const [],
    this.cursor = '',
    this.hasMore = true,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  UserPostsState copyWith({
    List<PostItem>? items,
    String? cursor,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    Object? error,
    bool clearError = false,
  }) {
    return UserPostsState(
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
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

  Future<GetPostListResp> _fetch(String cursor) {
    if (key.type == UserPostsListType.posts) {
      return repo.fetchUserPosts(
        userId: key.userId,
        cursor: cursor,
        pageSize: pageSize,
      );
    } else {
      return repo.fetchUserFavorites(
        userId: key.userId,
        cursor: cursor,
        pageSize: pageSize,
      );
    }
  }

  /// 服务端游标驱动：nextCursor 非空即还有下一页。
  bool _hasMoreFrom(GetPostListResp resp) => resp.nextCursor.isNotEmpty;

  Future<void> loadFirstPage() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _fetch('');
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: resp.list,
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadNextPage() async {
    if (!state.hasMore || state.isLoading || state.isRefreshing) return;
    final generation = _generation;
    // 与 feed/message 的 loadMore 一致：显式重试时先清掉上一次的失败态。
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _fetch(state.cursor);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...resp.list],
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(isRefreshing: true);
    try {
      final resp = await _fetch('');
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: resp.list,
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isRefreshing: false,
        isLoading: false,
        clearError: true,
      );
    } catch (_) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isRefreshing: false);
    }
  }
}

/// Provider.family
final userPostsProvider =
    StateNotifierProvider.autoDispose.family<
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
