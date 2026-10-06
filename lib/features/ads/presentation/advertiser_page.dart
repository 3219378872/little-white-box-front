import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ads_providers.dart';
import '../data/ad_labels.dart';
import 'ad_status_badges.dart';
import 'qualification_form.dart';
import '../application/ads_dependencies.dart';

/// 申请或修改广告主主体，并管理行业资质（FX-110）。
class AdvertiserPage extends ConsumerWidget {
  const AdvertiserPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advertiser = ref.watch(myAdvertiserProvider);
    return FScaffold(
      header: FHeader.nested(
        title: const Text('主体与资质'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/ads'),
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
            _AdvertiserForm(advertiser: advertiser),
            if (advertiser != null) ...[
              const SizedBox(height: AppTheme.space4),
              _Qualifications(advertiser: advertiser),
              const SizedBox(height: AppTheme.space4),
              QualificationForm(advertiser: advertiser),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdvertiserForm extends ConsumerStatefulWidget {
  final AdvertiserItem? advertiser;

  const _AdvertiserForm({required this.advertiser});

  @override
  ConsumerState<_AdvertiserForm> createState() => _AdvertiserFormState();
}

class _AdvertiserFormState extends ConsumerState<_AdvertiserForm> {
  late final TextEditingController _name;
  late Set<String> _markets;
  bool _busy = false;
  String? _key;
  String? _fingerprint;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.advertiser?.name ?? '');
    _markets = {...?widget.advertiser?.markets};
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.runes.length < 2 || name.runes.length > 64) {
      showAppError(context, '主体名称须为 2～64 个字符');
      return;
    }
    if (_markets.isEmpty) {
      showAppError(context, '至少选择一个投放市场');
      return;
    }
    final revision = widget.advertiser?.revision ?? 0;
    final markets = _markets.toList()..sort();
    final fingerprint = '$revision|$name|${markets.join(',')}';
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _key = newIdempotencyKey(24);
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adsRepositoryProvider)
          .applyAdvertiser(
            ApplyAdvertiserReq(
              name: name,
              markets: markets,
              expectedRevision: revision,
              idempotencyKey: _key!,
            ),
          );
      _fingerprint = null;
      if (!mounted) return;
      showAppSuccess(context, '已提交审核');
      ref.invalidate(myAdvertiserProvider);
    } on ApiException catch (error) {
      if (error.code != null) _fingerprint = null;
      if (!mounted) return;
      showAppError(context, switch (error.code) {
        ErrorCodes.contentVersionConflict => '主体信息已在别处更新，请刷新后再提交',
        ErrorCodes.advertiserExists => '你已经是广告主，请刷新后修改',
        _ => '提交失败：${error.message}',
      });
    } catch (error) {
      if (mounted) showAppError(context, '提交失败：${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final advertiser = widget.advertiser;
    final catalog =
        ref.watch(adPolicyCatalogProvider).value ?? AdPolicyCatalog.fallback;
    return AppSection(
      title: advertiser == null ? '申请成为广告主' : '广告主主体',
      trailing: advertiser == null
          ? null
          : ReviewStatusBadge(status: advertiser.reviewStatus),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (advertiser != null && advertiser.policyCodes.isNotEmpty) ...[
            FAlert(
              variant: FAlertVariant.destructive,
              icon: const Icon(FLucideIcons.circleAlert),
              title: const Text('未通过原因'),
              subtitle: Text(
                advertiser.policyCodes.map(catalog.titleOf).join('\n'),
              ),
            ),
            const SizedBox(height: AppTheme.space3),
          ],
          FTextField(
            key: const Key('advertiser-name'),
            control: FTextFieldControl.managed(controller: _name),
            label: const Text('主体名称'),
            hint: '公司或个人名称',
            maxLength: 64,
          ),
          const SizedBox(height: AppTheme.space3),
          Text('投放市场', style: theme.typography.body.sm),
          const SizedBox(height: AppTheme.space2),
          for (final market in catalog.markets)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.space2),
              child: FCheckbox(
                key: Key('advertiser-market-$market'),
                value: _markets.contains(market),
                label: Text(adMarketLabel(market)),
                onChange: (checked) => setState(() {
                  _markets = checked
                      ? {..._markets, market}
                      : ({..._markets}..remove(market));
                }),
              ),
            ),
          Text(
            '修改主体信息会重新送审。所有行业资质与主体一起作为一个对象审核。',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FButton(
            key: const Key('advertiser-submit'),
            onPress: _busy ? null : _submit,
            child: Text(
              _busy ? '提交中…' : (advertiser == null ? '提交申请' : '保存并送审'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Qualifications extends StatelessWidget {
  final AdvertiserItem advertiser;

  const _Qualifications({required this.advertiser});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AppSection(
      title: '行业资质',
      child: advertiser.qualifications.isEmpty
          ? Text(
              '尚未提交资质。金融、医疗等受监管行业需要目标市场资质才能送审广告。',
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            )
          : FItemGroup(
              children: [
                for (final qualification in advertiser.qualifications)
                  FItem(
                    title: Text(
                      '${adMarketLabel(qualification.market)} · '
                      '${adIndustryLabel(qualification.industry)}',
                    ),
                    subtitle: Text(
                      '有效期至 ${formatAdDate(qualification.validUntilMs.toInt())}',
                    ),
                    suffix: ReviewStatusBadge(status: qualification.status),
                  ),
              ],
            ),
    );
  }
}

/// UTC 日期 `YYYY-MM-DD`；0 表示未设置。
String formatAdDate(int ms) {
  if (ms <= 0) return '未设置';
  return formatUtcDate(ms);
}
