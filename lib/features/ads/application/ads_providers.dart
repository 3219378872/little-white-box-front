import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/ad_labels.dart';
import '../data/ads_repository.dart';

/// 政策码定义与可选市场、行业；请求失败时退回本地演示配置。
class AdPolicyCatalog {
  final String policyVersion;
  final List<AdPolicyCodeItem> codes;
  final List<String> markets;
  final List<String> industries;
  final bool demo;

  const AdPolicyCatalog({
    required this.policyVersion,
    required this.codes,
    required this.markets,
    required this.industries,
    required this.demo,
  });

  static final fallback = AdPolicyCatalog(
    policyVersion: '',
    codes: [
      for (final entry in adPolicyLabels.entries)
        AdPolicyCodeItem(code: entry.key, title: entry.value, category: ''),
    ],
    markets: adMarketLabels.keys.toList(),
    industries: adIndustryLabels.keys.toList(),
    demo: true,
  );

  String titleOf(String code) {
    for (final item in codes) {
      if (item.code == code && item.title.isNotEmpty) return item.title;
    }
    return adPolicyLabel(code);
  }
}

final adPolicyCatalogProvider = FutureProvider.autoDispose<AdPolicyCatalog>((
  ref,
) async {
  ref.watch(authenticatedSessionIdentityProvider);
  try {
    final resp = await ref.read(adsRepositoryProvider).listPolicies();
    if (resp.codes.isEmpty) return AdPolicyCatalog.fallback;
    return AdPolicyCatalog(
      policyVersion: resp.policyVersion,
      codes: resp.codes,
      markets: resp.markets.isEmpty
          ? AdPolicyCatalog.fallback.markets
          : resp.markets,
      industries: resp.industries.isEmpty
          ? AdPolicyCatalog.fallback.industries
          : resp.industries,
      demo: resp.demo,
    );
  } catch (_) {
    return AdPolicyCatalog.fallback;
  }
});

final myAdvertiserProvider = FutureProvider.autoDispose<AdvertiserItem?>((ref) {
  ref.watch(authenticatedSessionIdentityProvider);
  return ref.read(adsRepositoryProvider).getMyAdvertiser();
});

final adDetailProvider = FutureProvider.autoDispose.family<AdItem, String>((
  ref,
  adId,
) {
  ref.watch(authenticatedSessionIdentityProvider);
  return ref.read(adsRepositoryProvider).getAd(adId);
});

class AdsListState {
  final List<AdItem> ads;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final String cursor;
  final String? error;

  const AdsListState({
    this.ads = const [],
    this.loading = true,
    this.loadingMore = false,
    this.hasMore = false,
    this.cursor = '',
    this.error,
  });
}

/// 本人广告列表，按游标分页。
class AdsListNotifier extends StateNotifier<AdsListState> {
  final AdsRepository _repository;
  int _generation = 0;

  static const pageSize = 20;

  AdsListNotifier(this._repository, {bool loadImmediately = true})
    : super(const AdsListState()) {
    if (loadImmediately) refresh();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = AdsListState(ads: state.ads);
    try {
      final page = await _repository.listAds(pageSize: pageSize);
      if (!mounted || generation != _generation) return;
      state = AdsListState(
        ads: page.ads,
        loading: false,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdsListState(
        ads: state.ads,
        loading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final generation = _generation;
    final current = state;
    state = AdsListState(
      ads: current.ads,
      loading: false,
      loadingMore: true,
      hasMore: current.hasMore,
      cursor: current.cursor,
    );
    try {
      final page = await _repository.listAds(
        cursor: current.cursor,
        pageSize: pageSize,
      );
      if (!mounted || generation != _generation) return;
      // 游标翻页可能与已加载页重叠，按广告 ID 去重后追加。
      state = AdsListState(
        ads: appendUniqueBy(
          current.ads,
          page.ads,
          (ad) => jsonInt64Id(ad.adId),
        ),
        loading: false,
        hasMore: page.hasMore,
        cursor: page.nextCursor,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdsListState(
        ads: current.ads,
        loading: false,
        hasMore: current.hasMore,
        cursor: current.cursor,
        error: friendlyErrorMessage(error),
      );
    }
  }
}

final adsListProvider =
    StateNotifierProvider.autoDispose<AdsListNotifier, AdsListState>((ref) {
      ref.watch(authenticatedSessionIdentityProvider);
      return AdsListNotifier(ref.read(adsRepositoryProvider));
    });
