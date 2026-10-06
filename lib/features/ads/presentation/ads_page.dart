import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ads_providers.dart';
import '../data/ad_labels.dart';
import 'ad_status_badges.dart';

/// 广告主控制台首页：广告主状态与广告列表（FX-110）。
class AdsPage extends ConsumerWidget {
  const AdsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advertiser = ref.watch(myAdvertiserProvider);
    final ads = ref.watch(adsListProvider);
    return FScaffold(
      header: FHeader.nested(
        title: const Text('广告主控制台'),
        prefixes: [
          if (context.canPop())
            FHeaderAction.back(onPress: () => context.pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.refreshCw),
            semanticsLabel: '刷新',
            onPress: () {
              ref.invalidate(myAdvertiserProvider);
              ref.read(adsListProvider.notifier).refresh();
            },
          ),
        ],
      ),
      child: advertiser.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(myAdvertiserProvider),
        ),
        data: (advertiser) => ListView(
          padding: const EdgeInsets.all(AppTheme.pageInset),
          children: [
            _AdvertiserSummary(advertiser: advertiser),
            const SizedBox(height: AppTheme.space4),
            if (advertiser != null) ...[
              if (advertiser.approvedRevision > 0)
                FButton(
                  key: const Key('ads-new'),
                  prefix: const Icon(FLucideIcons.plus),
                  onPress: () async {
                    await context.push('/ads/new');
                    ref.read(adsListProvider.notifier).refresh();
                  },
                  child: const Text('新建广告'),
                )
              else
                const FAlert(
                  icon: Icon(FLucideIcons.info),
                  title: Text('广告主审核通过后才能创建广告'),
                ),
              const SizedBox(height: AppTheme.space4),
              _AdsList(state: ads),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdvertiserSummary extends StatelessWidget {
  final AdvertiserItem? advertiser;

  const _AdvertiserSummary({required this.advertiser});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final advertiser = this.advertiser;
    if (advertiser == null) {
      return AppSection(
        title: '还不是广告主',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '申请成为广告主并通过审核后，才能创建和投放广告。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: AppTheme.space3),
            FButton(
              key: const Key('ads-apply'),
              onPress: () => context.push('/ads/advertiser'),
              child: const Text('申请成为广告主'),
            ),
          ],
        ),
      );
    }
    return AppSection(
      title: advertiser.name,
      trailing: ReviewStatusBadge(status: advertiser.reviewStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInfoRow.text(
            label: '投放市场',
            text: advertiser.markets.map(adMarketLabel).join('、'),
          ),
          AppInfoRow.text(
            label: '行业资质',
            text: advertiser.qualifications.isEmpty
                ? '未提交'
                : '${advertiser.qualifications.length} 份',
          ),
          if (advertiser.policyCodes.isNotEmpty)
            AppInfoRow.text(
              label: '未通过原因',
              text: advertiser.policyCodes.map(adPolicyLabel).join('、'),
            ),
          const SizedBox(height: AppTheme.space2),
          FButton(
            key: const Key('ads-advertiser'),
            variant: FButtonVariant.outline,
            onPress: () => context.push('/ads/advertiser'),
            child: const Text('主体与资质'),
          ),
        ],
      ),
    );
  }
}

class _AdsList extends ConsumerWidget {
  final AdsListState state;

  const _AdsList({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final notifier = ref.read(adsListProvider.notifier);
    if (state.loading && state.ads.isEmpty) {
      return const LoadingView();
    }
    if (state.error != null && state.ads.isEmpty) {
      return ErrorView(message: state.error!, onRetry: notifier.refresh);
    }
    if (state.ads.isEmpty) {
      return Text(
        '还没有广告',
        textAlign: TextAlign.center,
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FItemGroup(
          children: [
            for (final ad in state.ads)
              FItem(
                key: Key('ads-item-${jsonInt64Id(ad.adId)}'),
                title: Text(
                  ad.latest.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: AppTheme.space1),
                  child: Wrap(
                    spacing: AppTheme.space1,
                    runSpacing: AppTheme.space1,
                    children: [
                      ReviewStatusBadge(status: ad.reviewStatus),
                      ServingStatusBadge(status: ad.servingStatus),
                      Text(
                        '${adMarketLabel(ad.latest.market)} · r${ad.revision}',
                        style: theme.typography.body.xs,
                      ),
                    ],
                  ),
                ),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: () async {
                  await context.push('/ads/${jsonInt64Id(ad.adId)}');
                  notifier.refresh();
                },
              ),
          ],
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppTheme.space2),
          Text(
            state.error!,
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.destructive,
            ),
          ),
        ],
        if (state.hasMore) ...[
          const SizedBox(height: AppTheme.space3),
          FButton(
            variant: FButtonVariant.outline,
            onPress: state.loadingMore ? null : notifier.loadMore,
            child: Text(state.loadingMore ? '加载中…' : '加载更多'),
          ),
        ],
      ],
    );
  }
}
