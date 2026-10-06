import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/collections/unique_by.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/search_models.dart';
import '../data/search_repository.dart';
import 'search_dependencies.dart';

enum SearchPhase { idle, loading, success, failure }

class SearchState {
  final SearchScope scope;
  final SearchPhase phase;
  final String keyword;
  final SearchResults results;
  final String? error;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  /// Keywords searched in this session, newest first. Kept in memory only.
  final List<String> recentKeywords;

  const SearchState({
    this.scope = SearchScope.all,
    this.phase = SearchPhase.idle,
    this.keyword = '',
    this.results = const SearchResults(),
    this.error,
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.recentKeywords = const [],
  });

  SearchState copyWith({
    SearchScope? scope,
    SearchPhase? phase,
    String? keyword,
    SearchResults? results,
    String? error,
    bool clearError = false,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
    List<String>? recentKeywords,
  }) {
    return SearchState(
      scope: scope ?? this.scope,
      phase: phase ?? this.phase,
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      recentKeywords: recentKeywords ?? this.recentKeywords,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchDataSource _repository;
  int _generation = 0;
  static const pageSize = 20;

  static const maxRecentKeywords = 8;

  SearchNotifier(this._repository) : super(const SearchState());

  /// Returns to the idle page and drops any in-flight result.
  void clear() {
    _generation++;
    state = SearchState(
      scope: state.scope,
      recentKeywords: state.recentKeywords,
    );
  }

  void clearRecent() {
    state = state.copyWith(recentKeywords: const []);
  }

  List<String> _withRecent(String keyword) => [
    keyword,
    ...state.recentKeywords.where((item) => item != keyword),
  ].take(maxRecentKeywords).toList();

  void selectScope(SearchScope scope) {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope, clearError: true);
    if (state.keyword.isNotEmpty) unawaited(search(state.keyword));
  }

  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    final generation = ++_generation;
    if (normalized.isEmpty) {
      state = state.copyWith(
        phase: SearchPhase.failure,
        keyword: '',
        results: const SearchResults(),
        error: '请输入搜索内容',
      );
      return;
    }

    state = state.copyWith(
      phase: SearchPhase.loading,
      keyword: normalized,
      recentKeywords: _withRecent(normalized),
      clearError: true,
      page: 1,
      hasMore: false,
      isLoadingMore: false,
    );
    try {
      final scope = state.scope;
      final results = await _repository.search(
        scope: scope,
        keyword: normalized,
        page: 1,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        phase: SearchPhase.success,
        results: results,
        clearError: true,
        page: 1,
        hasMore: _pageHasMore(scope, results, shown: results),
        isLoadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        phase: SearchPhase.failure,
        results: const SearchResults(),
        error: friendlyErrorMessage(error),
        hasMore: false,
        isLoadingMore: false,
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.phase != SearchPhase.success) {
      return;
    }
    final generation = _generation;
    final nextPage = state.page + 1;
    final scope = state.scope;
    final keyword = state.keyword;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.search(
        scope: scope,
        keyword: keyword,
        page: nextPage,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      final merged = _merge(state.results, page);
      state = state.copyWith(
        results: merged,
        page: nextPage,
        hasMore: _pageHasMore(scope, page, shown: merged),
        isLoadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  bool _pageHasMore(
    SearchScope scope,
    SearchResults page, {
    required SearchResults shown,
  }) {
    return switch (scope) {
      SearchScope.all => page.posts.length >= pageSize,
      SearchScope.users =>
        shown.total > shown.users.length ||
            (shown.total == 0 && page.users.length >= pageSize),
      SearchScope.tags => false,
    };
  }

  // 把下一页结果并入已展示结果，帖子、用户、标签各自按键去重。
  SearchResults _merge(SearchResults base, SearchResults page) {
    return SearchResults(
      posts: uniqueBy([
        ...base.posts,
        ...page.posts,
      ], (post) => post.id.toString()),
      users: uniqueBy([
        ...base.users,
        ...page.users,
      ], (user) => user.id.toString()),
      tags: uniqueBy([...base.tags, ...page.tags], (tag) => tag.name),
      total: page.total > 0 ? page.total : base.total,
      degraded: base.degraded || page.degraded,
      unavailableTypes: {
        ...base.unavailableTypes,
        ...page.unavailableTypes,
      }.toList(),
    );
  }

  Future<void> retry() => search(state.keyword);
}

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
      // Recent keywords are per session; a new account starts clean.
      ref.watch(authSessionIdentityProvider);
      return SearchNotifier(ref.read(searchRepositoryProvider));
    });
