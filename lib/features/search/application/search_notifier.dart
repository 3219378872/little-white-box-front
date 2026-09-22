import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/search_models.dart';
import '../data/search_repository.dart';

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

  const SearchState({
    this.scope = SearchScope.all,
    this.phase = SearchPhase.idle,
    this.keyword = '',
    this.results = const SearchResults(),
    this.error,
    this.page = 1,
    this.hasMore = false,
    this.isLoadingMore = false,
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
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchDataSource _repository;
  int _generation = 0;
  static const pageSize = 20;

  SearchNotifier(this._repository) : super(const SearchState());

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

  SearchResults _merge(SearchResults base, SearchResults page) {
    final postIds = <String>{};
    final userIds = <String>{};
    final tagNames = <String>{};
    return SearchResults(
      posts: [
        for (final post in [...base.posts, ...page.posts])
          if (postIds.add(post.id.toString())) post,
      ],
      users: [
        for (final user in [...base.users, ...page.users])
          if (userIds.add(user.id.toString())) user,
      ],
      tags: [
        for (final tag in [...base.tags, ...page.tags])
          if (tagNames.add(tag.name)) tag,
      ],
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

final searchRepositoryProvider = Provider<SearchDataSource>((ref) {
  return const SearchRepository();
});

final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
      return SearchNotifier(ref.read(searchRepositoryProvider));
    });
