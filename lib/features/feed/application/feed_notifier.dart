import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/feed_models.dart';
import '../data/feed_repository.dart';
import 'feed_dependencies.dart';

/// 单个信息流（推荐或关注）的分页状态：自然条目、广告槽位与两类分页游标。
class FeedState {
  /// 已加载的自然条目（已按帖子去重），带推荐上下文供行为上报。
  final List<FeedEntry> entries;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;

  /// 最近一次加载失败的提示；条目为空时页面整体显示错误态。
  final String? error;

  /// 失败发生在续翻：尾部重试应续翻下一页，而不是整体刷新。
  final bool loadMoreFailed;

  /// 本轮推荐快照的请求 ID；首屏由仓储生成，续翻沿用同一个以保证分页与上报口径一致。
  final String requestId;

  /// 推荐流的下一页游标。
  final String recommendCursor;

  /// 关注流的下一页游标（创建时间 + 帖子 ID）。
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

  /// 列表实际展示的行：自然条目按位置插入广告。
  List<FeedRow> get rows => mergeFeedRows(entries, sponsored);

  /// 复制并覆盖字段；[error] 需显式传 `clearError` 才清空。
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

/// 推荐/关注信息流的状态机：首屏、续翻、下拉刷新与广告隐藏的乐观更新。
///
/// 首屏与刷新递增 `_generation`，续翻与隐藏广告在异步返回后据此判断结果是否仍属于当前列表。
class FeedNotifier extends StateNotifier<FeedState> {
  final FeedPageRepository _repository;
  final FeedKind kind;
  final int pageSize;
  int _generation = 0;

  // 一次加载中连续遇到空页时最多向后翻的次数，防止异常游标导致无限请求。
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

  /// 首屏与重试：开新一轮请求快照，从第一页重建列表。
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

  /// 续翻下一页（列表接近底部时触发）；无更多或正在加载时忽略，失败标记为续翻失败。
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    // 续翻不开新代次：期间若发生首屏重载，本次结果作废。
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

  /// 下拉刷新：等同于首屏重载。
  Future<void> refresh() => loadInitial();

  /// 先在本地移除该广告的全部槽位，再调用 [send]；失败时按原位置恢复并抛出 [AdHideFailure]
  /// （FX-101）。期间列表已刷新时不再恢复，由新快照决定是否展示。
  Future<void> hideAd(Object adId, Future<void> Function() send) async {
    final generation = _generation;
    final target = jsonInt64Id(adId);
    // 乐观移除：同一广告可能占多个槽位，全部移除并记下原下标以便回滚。
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
      // 回滚：只在列表未被刷新时按原下标插回，已存在的槽位不重复插入。
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

  // 拉取一页；若本页没有条目但服务端表示还有更多，就沿游标继续向后翻，
  // 避免把中间的空页误显示成空列表或列表结束。期间收到的广告槽位一并累积。
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
      // 列表已被新一轮加载取代：直接返回，由调用方丢弃。
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
    // 达到翻页上限仍无可见条目：返回最后一页的游标，由页面决定是否继续续翻。
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

  // 首屏结果整体替换状态，顺带清掉加载与错误标记。
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

  // 服务端单页内可能重复返回同一帖子，只保留首次出现的位置。
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

/// 按信息流类型提供状态；推荐流匿名也可加载，关注流需要已登录，随会话身份重建。
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
