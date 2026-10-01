import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/error_view.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ads_providers.dart';
import '../data/ad_labels.dart';
import 'ad_status_badges.dart';

/// 最新版本与过审版本之间不同的字段（FX-110）。
class AdContentDiff {
  final String field;
  final String latest;
  final String approved;

  const AdContentDiff(this.field, this.latest, this.approved);
}

List<AdContentDiff> diffAdContent(
  AdContentItem latest,
  AdContentItem approved,
) {
  String media(AdContentItem item) => item.media
      .map(
        (m) => m.sha256.isEmpty
            ? jsonInt64Id(m.mediaId)
            : m.sha256.substring(0, 8),
      )
      .join('、');
  final pairs = [
    ('标题', latest.title, approved.title),
    ('正文', latest.body, approved.body),
    ('行动按钮', latest.cta, approved.cta),
    ('落地页', latest.landingUrl, approved.landingUrl),
    ('市场', latest.market, approved.market),
    ('行业', latest.industry, approved.industry),
    ('图片', media(latest), media(approved)),
  ];
  return [
    for (final (field, a, b) in pairs)
      if (a != b) AdContentDiff(field, a, b),
  ];
}

/// 广告详情：审核与投放状态、政策码原因、与过审版本的差异（FX-110）。
class AdDetailPage extends ConsumerWidget {
  final String adId;

  const AdDetailPage({super.key, required this.adId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ad = ref.watch(adDetailProvider(adId));
    return FScaffold(
      header: FHeader.nested(
        title: const Text('广告详情'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/ads'),
          ),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.refreshCw),
            semanticsLabel: '刷新',
            onPress: () => ref.invalidate(adDetailProvider(adId)),
          ),
        ],
      ),
      child: ad.when(
        loading: () => const Center(child: FCircularProgress()),
        error: (error, _) => ErrorView(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(adDetailProvider(adId)),
        ),
        data: (ad) => _AdDetail(ad: ad),
      ),
    );
  }
}

class _AdDetail extends ConsumerWidget {
  final AdItem ad;

  const _AdDetail({required this.ad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final catalog =
        ref.watch(adPolicyCatalogProvider).value ?? AdPolicyCatalog.fallback;
    final approved = ad.approved;
    final diffs = approved == null || ad.revision == ad.approvedRevision
        ? const <AdContentDiff>[]
        : diffAdContent(ad.latest, approved);
    final editable = ad.reviewStatus != 'appealing';
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pageInset),
      children: [
        AppSection(
          title: ad.latest.title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: AppTheme.space1,
                runSpacing: AppTheme.space1,
                children: [
                  ReviewStatusBadge(status: ad.reviewStatus),
                  ServingStatusBadge(status: ad.servingStatus),
                ],
              ),
              const SizedBox(height: AppTheme.space2),
              AppInfoRow.text(label: '最新版本', text: 'r${ad.revision}'),
              AppInfoRow.text(
                label: '过审版本',
                text: ad.approvedRevision > 0 ? 'r${ad.approvedRevision}' : '无',
              ),
              AppInfoRow.text(label: '当前可投放', text: ad.eligible ? '是' : '否'),
              if (ad.pauseReason.isNotEmpty)
                AppInfoRow.text(
                  label: '暂停原因',
                  text: adPauseReasonLabel(ad.pauseReason),
                ),
            ],
          ),
        ),
        if (ad.policyCodes.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space3),
          FAlert(
            key: const Key('ad-policy-reasons'),
            variant: FAlertVariant.destructive,
            icon: const Icon(FLucideIcons.circleAlert),
            title: const Text('未通过原因'),
            subtitle: Text(
              ad.policyCodes
                  .map((code) => '${catalog.titleOf(code)}（$code）')
                  .join('\n'),
            ),
          ),
        ],
        if (ad.reviewStatus == 'pending_review' && ad.approvedRevision > 0) ...[
          const SizedBox(height: AppTheme.space3),
          const FAlert(
            icon: Icon(FLucideIcons.info),
            title: Text('审核期间继续投放上一过审版本'),
          ),
        ],
        if (diffs.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space3),
          AppSection(
            key: const Key('ad-diff'),
            title: 'r${ad.revision} 与过审版本 r${ad.approvedRevision} 的差异',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppTheme.space2,
              children: [
                for (final diff in diffs)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        diff.field,
                        style: theme.typography.body.sm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '过审：${diff.approved.isEmpty ? '（空）' : diff.approved}',
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                      Text(
                        '最新：${diff.latest.isEmpty ? '（空）' : diff.latest}',
                        style: theme.typography.body.xs,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppTheme.space3),
        AppSection(
          title: '最新内容',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInfoRow.text(label: '广告主', text: ad.latest.advertiserName),
              AppInfoRow.text(label: '正文', text: ad.latest.body),
              AppInfoRow.text(label: '行动按钮', text: ad.latest.cta),
              AppInfoRow.text(label: '落地页', text: ad.latest.landingUrl),
              AppInfoRow.text(
                label: '市场',
                text: adMarketLabel(ad.latest.market),
              ),
              AppInfoRow.text(
                label: '行业',
                text: adIndustryLabel(ad.latest.industry),
              ),
              AppInfoRow.text(label: '图片', text: '${ad.latest.media.length} 张'),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        FButton(
          key: const Key('ad-edit'),
          prefix: const Icon(FLucideIcons.pencil),
          onPress: editable
              ? () async {
                  await context.push('/ads/${jsonInt64Id(ad.adId)}/edit');
                  ref.invalidate(adDetailProvider(jsonInt64Id(ad.adId)));
                }
              : null,
          child: const Text('编辑并重新送审'),
        ),
        const SizedBox(height: AppTheme.space6),
      ],
    );
  }
}
