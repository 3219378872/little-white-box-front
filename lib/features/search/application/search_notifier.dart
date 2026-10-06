import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/collections/unique_by.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/search_models.dart';
import '../data/search_repository.dart';
import 'search_dependencies.dart';

/// 搜索页主体的阶段：空闲（最近搜索）、首屏加载、成功出结果、失败可重试。
enum SearchPhase { idle, loading, success, failure }

/// 搜索页的不可变状态；`page`/`hasMore`/`isLoadingMore` 只服务于成功态下的加载更多。
///
/// 成功态里的 [error] 表示加载下一页失败，由列表尾部原地展示，不覆盖已有结果。
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

  /// 复制并覆盖字段；[error] 为 null 时保留原值，需显式传 `clearError` 才清空。
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

/// 搜索页状态机：负责首屏搜索、切换范围重搜、手动加载更多与会话内最近搜索。
///
/// 每次新搜索或清空都会递增 `_generation`，旧请求回来时据此丢弃，避免慢响应覆盖新关键词。
class SearchNotifier extends StateNotifier<SearchState> {
  final SearchDataSource _repository;
  // 搜索代次：新搜索/清空时递增，异步结果只在代次未变时落地。
  int _generation = 0;
  // 每页条数；标签范围没有分页，直接作为返回上限。
  static const pageSize = 20;

  // 最近搜索只保留最新若干条，防止空闲页无限增长。
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

  /// 清空会话内的最近搜索（空闲页「清空」按钮）。
  void clearRecent() {
    state = state.copyWith(recentKeywords: const []);
  }

  // 把关键词置顶到最近搜索并去重、截断。
  List<String> _withRecent(String keyword) => [
    keyword,
    ...state.recentKeywords.where((item) => item != keyword),
  ].take(maxRecentKeywords).toList();

  /// 切换搜索范围；已有关键词时立即按新范围重搜，否则只记住范围。
  void selectScope(SearchScope scope) {
    if (scope == state.scope) return;
    state = state.copyWith(scope: scope, clearError: true);
    if (state.keyword.isNotEmpty) unawaited(search(state.keyword));
  }

  /// 以 [keyword] 发起新的首屏搜索（提交、点最近搜索/标签、重试都走这里）。
  ///
  /// 空关键词直接进入失败态并提示，不发请求；成功后从第 1 页重新计分页。
  Future<void> search(String keyword) async {
    final normalized = keyword.trim();
    // 先占用新代次，使之前所有在途请求的结果失效。
    final generation = ++_generation;
    // 空白关键词：本地拦截，给出输入提示。
    if (normalized.isEmpty) {
      state = state.copyWith(
        phase: SearchPhase.failure,
        keyword: '',
        results: const SearchResults(),
        error: '请输入搜索内容',
      );
      return;
    }

    // 进入加载态：记入最近搜索，并把分页重置到第 1 页。
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
      // 代次已变（用户又搜了别的或清空了）：丢弃本次结果。
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
      // 首屏失败：清空结果进入失败态，由页面给出重试。
      state = state.copyWith(
        phase: SearchPhase.failure,
        results: const SearchResults(),
        error: friendlyErrorMessage(error),
        hasMore: false,
        isLoadingMore: false,
      );
    }
  }

  /// 成功态下加载下一页（列表尾部按钮触发）；无更多、正在加载或非成功态时忽略。
  ///
  /// 失败只记录 [SearchState.error] 供尾部重试，已展示的结果保持不变。
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.isLoadingMore ||
        state.phase != SearchPhase.success) {
      return;
    }
    // 加载更多不开新代次，只要期间没有新搜索结果就并入当前列表；请求参数在发起时冻结。
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
      // 代次未变：与已展示结果合并去重，并推进页码。
      final merged = _merge(state.results, page);
      state = state.copyWith(
        results: merged,
        page: nextPage,
        hasMore: _pageHasMore(scope, page, shown: merged),
        isLoadingMore: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      // 下一页失败：保留已有结果，错误交给列表尾部重试。
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  // 判断是否还有下一页：综合页按帖子是否满页推断，用户页优先用服务端 total，
  // total 缺失（为 0）时退回满页推断；标签接口只有 limit 没有分页。
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

  /// 失败态重试：用当前关键词重新发起首屏搜索。
  Future<void> retry() => search(state.keyword);
}

/// 搜索页状态；随登录会话身份重建。
final searchNotifierProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) {
      // Recent keywords are per session; a new account starts clean.
      ref.watch(authSessionIdentityProvider);
      return SearchNotifier(ref.read(searchRepositoryProvider));
    });
