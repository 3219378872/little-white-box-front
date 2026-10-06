import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/ads_repository.dart';
import 'ads_dependencies.dart';

/// 政策码定义与可选市场、行业。
///
/// 接口不可用时的本地演示配置与中文标题回退属于展示文案，由 presentation 的
/// `resolveAdPolicyCatalog` 与 `titleOf` 补齐，本层只承载服务端结果。
class AdPolicyCatalog {
  final String policyVersion;
  final List<AdPolicyCodeItem> codes;
  final List<String> markets;
  final List<String> industries;

  /// 服务端声明政策码、市场与阈值仅为演示配置。
  final bool demo;

  const AdPolicyCatalog({
    required this.policyVersion,
    required this.codes,
    required this.markets,
    required this.industries,
    required this.demo,
  });

  /// 目录内 [code] 的非空标题；没有时返回 null，由调用方选择回退文案。
  String? titleFor(String code) {
    for (final item in codes) {
      if (item.code == code && item.title.isNotEmpty) return item.title;
    }
    return null;
  }
}

/// 服务端政策目录；请求失败或没有政策码时为 null，展示层退回本地演示配置。
final adPolicyCatalogProvider = FutureProvider.autoDispose<AdPolicyCatalog?>((
  ref,
) async {
  // 登录身份变化（登出、换号）时重建，不沿用上一身份的结果。
  ref.watch(authenticatedSessionIdentityProvider);
  try {
    final resp = await ref.read(adsRepositoryProvider).listPolicies();
    if (resp.codes.isEmpty) return null;
    return AdPolicyCatalog(
      policyVersion: resp.policyVersion,
      codes: resp.codes,
      markets: resp.markets,
      industries: resp.industries,
      demo: resp.demo,
    );
  } catch (_) {
    // 目录只影响文案与可选项，失败不阻断页面。
    return null;
  }
});

/// 本人广告主主体，尚未申请时为 null；主体与资质写命令成功后被 invalidate。
final myAdvertiserProvider = FutureProvider.autoDispose<AdvertiserItem?>((ref) {
  ref.watch(authenticatedSessionIdentityProvider);
  return ref.read(adsRepositoryProvider).getMyAdvertiser();
});

/// 按广告 ID 读取详情；保存与申诉命令完成后 invalidate 以读取最新版本与审核状态。
final adDetailProvider = FutureProvider.autoDispose.family<AdItem, String>((
  ref,
  adId,
) {
  ref.watch(authenticatedSessionIdentityProvider);
  return ref.read(adsRepositoryProvider).getAd(adId);
});

/// 本人广告列表：[isLoading] 为首屏加载，[isLoadingMore] 为翻页，[error] 为最近一次失败。
class AdsListState {
  final List<AdItem> ads;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;

  /// 下一页游标；与 [hasMore] 一起由服务端分页结果给出。
  final String cursor;
  final String? error;

  const AdsListState({
    this.ads = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.cursor = '',
    this.error,
  });

  AdsListState copyWith({
    List<AdItem>? ads,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? cursor,
    String? error,
    bool clearError = false,
  }) {
    return AdsListState(
      ads: ads ?? this.ads,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 本人广告列表，按游标分页。
class AdsListNotifier extends StateNotifier<AdsListState> {
  final AdsRepository _repository;
  // 每次 loadInitial 递增；旧代请求的结果到达时直接丢弃。
  int _generation = 0;

  static const pageSize = 20;

  AdsListNotifier(this._repository, {bool loadImmediately = true})
    : super(const AdsListState()) {
    if (loadImmediately) loadInitial();
  }

  /// 首屏、重试与返回列表时重新读取第一页；新一代请求使进行中的旧请求失效。
  Future<void> loadInitial() async {
    final generation = ++_generation;
    // 保留已有条目，避免刷新时列表闪空。
    state = AdsListState(ads: state.ads);
    try {
      final page = await _repository.listAds(pageSize: pageSize);
      if (!mounted || generation != _generation) return;
      state = AdsListState(
        ads: page.ads,
        isLoading: false,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdsListState(
        ads: state.ads,
        isLoading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  /// 按游标追加下一页；失败保留已加载条目与游标，可再次重试。
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    // 翻页沿用当前代；期间若重新加载首屏，本次结果作废。
    final generation = _generation;
    final current = state;
    state = current.copyWith(isLoadingMore: true, clearError: true);
    try {
      final page = await _repository.listAds(
        cursor: current.cursor,
        pageSize: pageSize,
      );
      if (!mounted || generation != _generation) return;
      // 游标翻页可能与已加载页重叠，按广告 ID 去重后追加。
      state = current.copyWith(
        ads: appendUniqueBy(
          current.ads,
          page.ads,
          (ad) => jsonInt64Id(ad.adId),
        ),
        hasMore: page.hasMore,
        cursor: page.nextCursor,
        clearError: true,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = current.copyWith(error: friendlyErrorMessage(error));
    }
  }
}

/// 本人广告列表；登录身份变化时重建并重新加载首屏。
final adsListProvider =
    StateNotifierProvider.autoDispose<AdsListNotifier, AdsListState>((ref) {
      ref.watch(authenticatedSessionIdentityProvider);
      return AdsListNotifier(ref.read(adsRepositoryProvider));
    });
