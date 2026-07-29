import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const SearchState({
    this.scope = SearchScope.all,
    this.phase = SearchPhase.idle,
    this.keyword = '',
    this.results = const SearchResults(),
    this.error,
  });

  SearchState copyWith({
    SearchScope? scope,
    SearchPhase? phase,
    String? keyword,
    SearchResults? results,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      scope: scope ?? this.scope,
      phase: phase ?? this.phase,
      keyword: keyword ?? this.keyword,
      results: results ?? this.results,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final SearchDataSource _repository;
  int _generation = 0;

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
    );
    try {
      final results = await _repository.search(
        scope: state.scope,
        keyword: normalized,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        phase: SearchPhase.success,
        results: results,
        clearError: true,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        phase: SearchPhase.failure,
        results: const SearchResults(),
        error: friendlyErrorMessage(error),
      );
    }
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
