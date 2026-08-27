import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/feed_models.dart';
import '../data/feed_repository.dart';

class FeedState {
  final List<FeedEntry> entries;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final bool loadMoreFailed;
  final String requestId;
  final String recommendCursor;
  final FollowFeedCursor followCursor;

  const FeedState({
    this.entries = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreFailed = false,
    this.requestId = '',
    this.recommendCursor = '',
    this.followCursor = const FollowFeedCursor(),
  });

  FeedState copyWith({
    List<FeedEntry>? entries,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    bool? loadMoreFailed,
    String? requestId,
    String? recommendCursor,
    FollowFeedCursor? followCursor,
  }) {
    return FeedState(
      entries: entries ?? this.entries,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      requestId: requestId ?? this.requestId,
      recommendCursor: recommendCursor ?? this.recommendCursor,
      followCursor: followCursor ?? this.followCursor,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final FeedPageRepository _repository;
  final FeedKind kind;
  final int pageSize;
  int _generation = 0;

  static const _emptyPageAdvanceLimit = 8;

  FeedNotifier({
    required FeedPageRepository repository,
    required this.kind,
    this.pageSize = 20,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const FeedState()) {
    if (loadImmediately) unawaited(loadInitial());
  }

  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      loadMoreFailed: false,
      clearError: true,
    );
    try {
      final result = await _fetchUntilVisible(
        generation: generation,
        requestId: '',
        recommendCursor: '',
        followCursor: const FollowFeedCursor(),
        positionOffset: 0,
      );
      if (!mounted || generation != _generation) return;
      state = _fromResult(result);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        loadMoreFailed: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final generation = _generation;
    state = state.copyWith(
      isLoadingMore: true,
      loadMoreFailed: false,
      clearError: true,
    );
    try {
      final result = await _fetchUntilVisible(
        generation: generation,
        requestId: state.requestId,
        recommendCursor: state.recommendCursor,
        followCursor: state.followCursor,
        positionOffset: state.entries.length,
      );
      if (!mounted || generation != _generation) return;
      final seen = state.entries.map((entry) => jsonInt64Id(entry.post.id)).toSet();
      final additions = result.items
          .where((entry) => seen.add(jsonInt64Id(entry.post.id)))
          .toList();
      state = state.copyWith(
        entries: [...state.entries, ...additions],
        hasMore: result.hasMore,
        isLoadingMore: false,
        loadMoreFailed: false,
        requestId: result.requestId,
        recommendCursor: result.recommendCursor,
        followCursor: result.followCursor,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreFailed: true,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refresh() => loadInitial();

  Future<FeedPageResult> _fetchUntilVisible({
    required int generation,
    required String requestId,
    required String recommendCursor,
    required FollowFeedCursor followCursor,
    required int positionOffset,
  }) async {
    var nextRequestId = requestId;
    var nextRecommend = recommendCursor;
    var nextFollow = followCursor;
    var offset = positionOffset;
    FeedPageResult? last;
    for (var attempt = 0; attempt < _emptyPageAdvanceLimit; attempt++) {
      final result = await _repository.fetchPage(
        kind: kind,
        pageSize: pageSize,
        requestId: nextRequestId,
        recommendCursor: nextRecommend,
        followCursor: nextFollow,
        positionOffset: offset,
      );
      last = result;
      if (!mounted || generation != _generation) return result;
      final visible = _dedupe(result.items);
      if (visible.isNotEmpty || !result.hasMore) {
        return FeedPageResult(
          items: visible,
          hasMore: result.hasMore,
          requestId: result.requestId,
          recommendCursor: result.recommendCursor,
          followCursor: result.followCursor,
        );
      }
      nextRequestId = result.requestId;
      nextRecommend = result.recommendCursor;
      nextFollow = result.followCursor;
      offset += result.items.length;
    }
    final exhausted = last!;
    return FeedPageResult(
      items: _dedupe(exhausted.items),
      hasMore: exhausted.hasMore,
      requestId: exhausted.requestId,
      recommendCursor: exhausted.recommendCursor,
      followCursor: exhausted.followCursor,
    );
  }

  FeedState _fromResult(FeedPageResult result) {
    return FeedState(
      entries: _dedupe(result.items),
      hasMore: result.hasMore,
      requestId: result.requestId,
      recommendCursor: result.recommendCursor,
      followCursor: result.followCursor,
    );
  }

  static List<FeedEntry> _dedupe(List<FeedEntry> items) {
    final seen = <String>{};
    return items
        .where((entry) => seen.add(jsonInt64Id(entry.post.id)))
        .toList();
  }
}

final feedRepositoryProvider = Provider<FeedPageRepository>((ref) {
  return FeedRepository(identityStore: ref.read(clientIdentityStoreProvider));
});

final feedNotifierProvider =
    StateNotifierProvider.autoDispose.family<FeedNotifier, FeedState,
        FeedKind>((
      ref,
      kind,
    ) {
      final canLoad = kind == FeedKind.recommend
          ? true
          : ref.watch(
              authNotifierProvider.select((state) => state.isAuthenticated),
            );
      return FeedNotifier(
        repository: ref.read(feedRepositoryProvider),
        kind: kind,
        loadImmediately: canLoad,
      );
    });
