import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
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

  /// 已加载的广告槽位；与自然条目分开保存，展示时由 [rows] 合并（FX-103）。
  final List<SponsoredSlot> sponsored;

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
    this.sponsored = const [],
  });

  List<FeedRow> get rows => mergeFeedRows(entries, sponsored);

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
    List<SponsoredSlot>? sponsored,
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
      sponsored: sponsored ?? this.sponsored,
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
      // 追加新页时丢弃已展示的帖子，保持现有条目顺序不变。
      state = state.copyWith(
        entries: appendUniqueBy(
          state.entries,
          result.items,
          (entry) => jsonInt64Id(entry.post.id),
        ),
        sponsored: _appendSponsored(state.sponsored, result.sponsored),
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

  /// 先在本地移除该广告的全部槽位，再调用 [send]；失败时按原位置恢复并抛出 [AdHideFailure]
  /// （FX-101）。期间列表已刷新时不再恢复，由新快照决定是否展示。
  Future<void> hideAd(Object adId, Future<void> Function() send) async {
    final generation = _generation;
    final target = jsonInt64Id(adId);
    final removed = <(int, SponsoredSlot)>[];
    final remaining = <SponsoredSlot>[];
    for (final (index, slot) in state.sponsored.indexed) {
      if (jsonInt64Id(slot.ad.adId) == target) {
        removed.add((index, slot));
      } else {
        remaining.add(slot);
      }
    }
    if (removed.isEmpty) return;
    state = state.copyWith(sponsored: remaining);
    try {
      await send();
    } catch (error) {
      final restore = mounted && generation == _generation;
      if (restore) {
        final restored = [...state.sponsored];
        final present = restored.map((slot) => slot.key).toSet();
        for (final (index, slot) in removed) {
          if (present.contains(slot.key)) continue;
          restored.insert(index.clamp(0, restored.length), slot);
        }
        state = state.copyWith(sponsored: restored);
      }
      throw AdHideFailure(restored: restore, cause: error);
    }
  }

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
    var sponsored = const <SponsoredSlot>[];
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
      sponsored = _appendSponsored(sponsored, result.sponsored);
      final visible = _dedupe(result.items);
      if (visible.isNotEmpty || !result.hasMore) {
        return FeedPageResult(
          items: visible,
          hasMore: result.hasMore,
          requestId: result.requestId,
          recommendCursor: result.recommendCursor,
          followCursor: result.followCursor,
          sponsored: sponsored,
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
      sponsored: sponsored,
    );
  }

  FeedState _fromResult(FeedPageResult result) {
    return FeedState(
      entries: _dedupe(result.items),
      hasMore: result.hasMore,
      requestId: result.requestId,
      recommendCursor: result.recommendCursor,
      followCursor: result.followCursor,
      sponsored: result.sponsored,
    );
  }

  // 新页广告槽位按槽位键追加，已展示的槽位保持原位。
  static List<SponsoredSlot> _appendSponsored(
    List<SponsoredSlot> current,
    List<SponsoredSlot> additions,
  ) {
    if (additions.isEmpty) return current;
    return appendUniqueBy(current, additions, (slot) => slot.key);
  }

  // 同一帖子在推荐与关注合流中可能重复，只保留首次出现的位置。
  static List<FeedEntry> _dedupe(List<FeedEntry> items) {
    return uniqueBy(items, (entry) => jsonInt64Id(entry.post.id));
  }
}

/// 隐藏广告失败；[restored] 表示广告是否已放回原位置。
class AdHideFailure implements Exception {
  final bool restored;
  final Object cause;

  const AdHideFailure({required this.restored, required this.cause});

  @override
  String toString() => 'AdHideFailure(restored: $restored, cause: $cause)';
}

final feedRepositoryProvider = Provider<FeedPageRepository>((ref) {
  return FeedRepository(identityStore: ref.read(clientIdentityStoreProvider));
});

final feedNotifierProvider = StateNotifierProvider.autoDispose
    .family<FeedNotifier, FeedState, FeedKind>((ref, kind) {
      final identity = ref.watch(authSessionIdentityProvider);
      final authenticatedIdentity = ref.watch(
        authenticatedSessionIdentityProvider,
      );
      final canLoad =
          identity != null &&
          (kind == FeedKind.recommend || authenticatedIdentity != null);
      return FeedNotifier(
        repository: ref.read(feedRepositoryProvider),
        kind: kind,
        loadImmediately: canLoad,
      );
    });
