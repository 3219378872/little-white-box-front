import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/user_repository.dart';
import 'profile_dependencies.dart';

enum UserPostsListType { posts, favorites }

class UserPostsKey {
  final Object userId;
  final UserPostsListType type;
  const UserPostsKey({required this.userId, required this.type});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPostsKey &&
          jsonInt64Id(other.userId) == jsonInt64Id(userId) &&
          other.type == type);

  @override
  int get hashCode => Object.hash(jsonInt64Id(userId), type);
}

/// 个人页帖子/收藏列表：[isLoading] 为首屏加载，[isLoadingMore] 为翻页，
/// [isRefreshing] 为保留现有条目的下拉/回访刷新。
class UserPostsState {
  final List<PostItem> items;

  /// 下一页游标；空串表示没有更多（与网关 nextCursor 语义一致）。
  final String cursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isRefreshing;

  /// 最近一次失败的原始错误文本；展示时再经 friendlyErrorMessage 处理。
  final String? error;

  const UserPostsState({
    this.items = const [],
    this.cursor = '',
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.error,
  });

  UserPostsState copyWith({
    List<PostItem>? items,
    String? cursor,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isRefreshing,
    String? error,
    bool clearError = false,
  }) {
    return UserPostsState(
      items: items ?? this.items,
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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
  static const _emptyPageAdvanceLimit = 8;

  UserPostsNotifier({required this.repo, required this.key, this.pageSize = 20})
    : super(const UserPostsState());

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

  /// 收藏会在分页之后丢掉未发布帖子。空页但还有游标时继续向后翻，
  /// 避免把「这一页被滤空」画成没有收藏或列表结束。
  Future<GetPostListResp> _fetchVisible(String cursor) async {
    var next = cursor;
    late GetPostListResp resp;
    for (var attempt = 0; attempt < _emptyPageAdvanceLimit; attempt++) {
      resp = await _fetch(next);
      if (resp.list.isNotEmpty || resp.nextCursor.isEmpty) return resp;
      if (resp.nextCursor == next) return resp;
      next = resp.nextCursor;
    }
    return resp;
  }

  /// 首屏与错误重试：从第一页重建列表，新一代请求使进行中的翻页与刷新失效。
  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      isRefreshing: false,
      clearError: true,
    );
    try {
      final resp = await _fetchVisible('');
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: _deduplicate(resp.list),
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 按游标追加下一页；失败保留已加载条目与游标，由用户点重试再发。
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoading ||
        state.isLoadingMore ||
        state.isRefreshing) {
      return;
    }
    final generation = _generation;
    // 与 feed/message 的 loadMore 一致：显式重试时先清掉上一次的失败态。
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final resp = await _fetchVisible(state.cursor);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: _deduplicate([...state.items, ...resp.list]),
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isLoadingMore: false,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// 保留现有条目重新读取第一页（下拉刷新、切回标签、从子页面返回）。
  Future<void> refresh() async {
    final generation = ++_generation;
    // 新一代请求让进行中的首屏/翻页失效，同时释放它们的加载标记。
    state = state.copyWith(
      isRefreshing: true,
      isLoading: false,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final resp = await _fetchVisible('');
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        items: _deduplicate(resp.list),
        cursor: resp.nextCursor,
        hasMore: _hasMoreFrom(resp),
        isRefreshing: false,
        clearError: true,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isRefreshing: false, error: error.toString());
    }
  }

  // 按帖子 ID 去重，翻页边界上重复返回的帖子只保留首个。
  static List<PostItem> _deduplicate(List<PostItem> items) {
    return uniqueBy(items, (item) => jsonInt64Id(item.id));
  }
}

/// Provider.family
final userPostsProvider = StateNotifierProvider.autoDispose
    .family<UserPostsNotifier, UserPostsState, UserPostsKey>((ref, key) {
      ref.watch(authSessionIdentityProvider);
      final notifier = UserPostsNotifier(
        repo: ref.read(userPostsRepositoryProvider),
        key: key,
      );
      notifier.loadInitial();
      return notifier;
    });
