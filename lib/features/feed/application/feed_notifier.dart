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
  final String requestId;
  final String recommendCursor;
  final FollowFeedCursor followCursor;

  const FeedState({
    this.entries = const [],
    this.hasMore = true,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
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
      clearError: true,
    );
    try {
      final result = await _repository.fetchPage(
        kind: kind,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      state = _fromResult(result);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _repository.fetchPage(
        kind: kind,
        pageSize: pageSize,
        requestId: state.requestId,
        recommendCursor: state.recommendCursor,
        followCursor: state.followCursor,
        positionOffset: state.entries.length,
      );
      if (generation != _generation) return;
      final seen = state.entries.map((entry) => jsonInt64Id(entry.post.id)).toSet();
      final additions = result.items
          .where((entry) => seen.add(jsonInt64Id(entry.post.id)))
          .toList();
      state = state.copyWith(
        entries: [...state.entries, ...additions],
        hasMore: result.hasMore,
        isLoadingMore: false,
        requestId: result.requestId,
        recommendCursor: result.recommendCursor,
        followCursor: result.followCursor,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> refresh() => loadInitial();

  FeedState _fromResult(FeedPageResult result) {
    final seen = <String>{};
    final entries = result.items
        .where((entry) => seen.add(jsonInt64Id(entry.post.id)))
        .toList();
    return FeedState(
      entries: entries,
      hasMore: result.hasMore,
      requestId: result.requestId,
      recommendCursor: result.recommendCursor,
      followCursor: result.followCursor,
    );
  }
}

final feedRepositoryProvider = Provider<FeedPageRepository>((ref) {
  return FeedRepository(identityStore: ref.read(clientIdentityStoreProvider));
});

final feedNotifierProvider =
    StateNotifierProvider.family<FeedNotifier, FeedState, FeedKind>((
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
