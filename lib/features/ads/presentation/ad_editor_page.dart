import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_choice_button.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ads_providers.dart';
import '../data/ad_labels.dart';
import '../data/ads_repository.dart';

/// 单条广告最多 3 张创意图（与 ad-rpc 一致）。
const maxAdCreatives = 3;

final adAssetBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, assetId) {
      return ref.read(adsRepositoryProvider).readAsset(assetId);
    });

/// 广告文案的客户端校验；返回首个错误，服务端仍做最终校验。
String? validateAdDraft({
  required String title,
  required String body,
  required String cta,
  required String landingUrl,
}) {
  int length(String value) => value.trim().runes.length;
  if (length(title) < 1 || length(title) > 100) return '标题须为 1～100 个字符';
  if (length(body) < 1 || length(body) > 500) return '正文须为 1～500 个字符';
  if (length(cta) < 1 || length(cta) > 32) return '行动按钮须为 1～32 个字符';
  final uri = Uri.tryParse(landingUrl.trim());
  if (landingUrl.trim().length > 2048 ||
      uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return '落地页须为 https 地址';
  }
  return null;
}

/// 创建或编辑广告；提交带 expectedRevision 与幂等键（FX-110）。
class AdEditorPage extends ConsumerWidget {
  final String? adId;

  const AdEditorPage({super.key, this.adId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advertiser = ref.watch(myAdvertiserProvider);
    final existing = adId == null ? null : ref.watch(adDetailProvider(adId!));
    final title = adId == null ? '新建广告' : '编辑广告';
    Widget scaffold(Widget child) => FScaffold(
      header: FHeader.nested(
        title: Text(title),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/ads'),
          ),
        ],
      ),
      child: child,
    );
    final loading =
        advertiser.isLoading || (existing != null && existing.isLoading);
    final error = advertiser.error ?? existing?.error;
    if (loading) return scaffold(const LoadingView());
    if (error != null) {
      return scaffold(
        ErrorView(
          message: friendlyErrorMessage(error),
          onRetry: () {
            ref.invalidate(myAdvertiserProvider);
            if (adId != null) ref.invalidate(adDetailProvider(adId!));
          },
        ),
      );
    }
    final owner = advertiser.value;
    if (owner == null) {
      return scaffold(const EmptyView(message: '请先申请成为广告主'));
    }
    return scaffold(
      _AdEditorForm(advertiser: owner, existing: existing?.value),
    );
  }
}

class _AdEditorForm extends ConsumerStatefulWidget {
  final AdvertiserItem advertiser;
  final AdItem? existing;

  const _AdEditorForm({required this.advertiser, required this.existing});

  @override
  ConsumerState<_AdEditorForm> createState() => _AdEditorFormState();
}

class _AdEditorFormState extends ConsumerState<_AdEditorForm> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _cta;
  late final TextEditingController _landing;
  late String _market;
  late String _industry;
  late List<Object> _mediaIds;
  bool _busy = false;
  bool _uploading = false;
  String? _key;
  String? _fingerprint;
  int _uploadGeneration = 0;

  AdItem? get _existing => widget.existing;

  @override
  void initState() {
    super.initState();
    final latest = _existing?.latest;
    _title = TextEditingController(text: latest?.title ?? '');
    _body = TextEditingController(text: latest?.body ?? '');
    _cta = TextEditingController(text: latest?.cta ?? '');
    _landing = TextEditingController(text: latest?.landingUrl ?? 'https://');
    final markets = widget.advertiser.markets;
    _market = latest?.market.isNotEmpty == true
        ? latest!.market
        : (markets.isEmpty ? 'US' : markets.first);
    _industry = latest?.industry.isNotEmpty == true
        ? latest!.industry
        : 'GENERAL';
    _mediaIds = [...?latest?.media.map((media) => media.mediaId)];
  }

  @override
  void dispose() {
    _uploadGeneration++;
    _title.dispose();
    _body.dispose();
    _cta.dispose();
    _landing.dispose();
    super.dispose();
  }

  Future<void> _addCreative() async {
    if (_mediaIds.length >= maxAdCreatives) return;
    final file = await ref
        .read(adAssetPickerProvider)
        .pick(AdAssetKind.creative);
    if (file == null || !mounted) return;
    final generation = ++_uploadGeneration;
    setState(() => _uploading = true);
    try {
      final asset = await ref
          .read(adsRepositoryProvider)
          .uploadAsset(
            kind: AdAssetKind.creative,
            file: file,
            idempotencyKey: newIdempotencyKey(24),
            isCurrent: () => mounted && generation == _uploadGeneration,
          );
      if (!mounted || generation != _uploadGeneration) return;
      setState(() => _mediaIds = [..._mediaIds, asset.assetId]);
    } catch (error) {
      if (mounted) {
        showAppError(context, '图片上传失败：${friendlyErrorMessage(error)}');
      }
    } finally {
      if (mounted && generation == _uploadGeneration) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _submit() async {
    final invalid = validateAdDraft(
      title: _title.text,
      body: _body.text,
      cta: _cta.text,
      landingUrl: _landing.text,
    );
    if (invalid != null) {
      showAppError(context, invalid);
      return;
    }
    final existing = _existing;
    final fingerprint = [
      existing?.revision ?? 0,
      _title.text.trim(),
      _body.text.trim(),
      _cta.text.trim(),
      _landing.text.trim(),
      _market,
      _industry,
      _mediaIds.map(jsonInt64Id).join(','),
    ].join('|');
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _key = newIdempotencyKey(24);
    }
    setState(() => _busy = true);
    try {
      final repository = ref.read(adsRepositoryProvider);
      final AdItem saved;
      if (existing == null) {
        saved = await repository.createAd(
          CreateAdReq(
            title: _title.text.trim(),
            body: _body.text.trim(),
            cta: _cta.text.trim(),
            landingUrl: _landing.text.trim(),
            mediaIds: _mediaIds,
            market: _market,
            industry: _industry,
            startMs: 0,
            endMs: 0,
            idempotencyKey: _key!,
          ),
        );
      } else {
        saved = await repository.updateAd(
          existing.adId,
          UpdateAdReq(
            adId: existing.adId,
            expectedRevision: existing.revision,
            title: _title.text.trim(),
            body: _body.text.trim(),
            cta: _cta.text.trim(),
            landingUrl: _landing.text.trim(),
            mediaIds: _mediaIds,
            market: _market,
            industry: _industry,
            startMs: existing.startMs,
            endMs: existing.endMs,
            idempotencyKey: _key!,
          ),
        );
      }
      _fingerprint = null;
      if (!mounted) return;
      showAppSuccess(context, '已提交审核');
      final id = jsonInt64Id(saved.adId);
      ref.invalidate(adDetailProvider(id));
      if (existing != null && context.canPop()) {
        // The detail page below refreshes itself when the editor closes.
        context.pop();
      } else {
        context.pushReplacement('/ads/$id');
      }
    } on ApiException catch (error) {
      if (error.code != null) _fingerprint = null;
      if (mounted) showAppError(context, adWriteErrorMessage(error));
    } catch (error) {
      if (mounted) showAppError(context, '提交失败：${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final catalog =
        ref.watch(adPolicyCatalogProvider).value ?? AdPolicyCatalog.fallback;
    final existing = _existing;
    final servingApproved = existing != null && existing.approvedRevision > 0;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pageInset),
      children: [
        if (servingApproved) ...[
          const FAlert(
            key: Key('ad-editor-serving-notice'),
            icon: Icon(FLucideIcons.info),
            title: Text('审核期间继续投放上一过审版本'),
            subtitle: Text('新版本通过审核后才会替换正在投放的内容。'),
          ),
          const SizedBox(height: AppTheme.space3),
        ],
        AppSection(
          title: '广告内容',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppTheme.space3,
            children: [
              FTextField(
                key: const Key('ad-title'),
                control: FTextFieldControl.managed(controller: _title),
                label: const Text('标题'),
                maxLength: 100,
              ),
              FTextField(
                key: const Key('ad-body'),
                control: FTextFieldControl.managed(controller: _body),
                label: const Text('正文'),
                maxLines: 5,
                maxLength: 500,
              ),
              FTextField(
                key: const Key('ad-cta'),
                control: FTextFieldControl.managed(controller: _cta),
                label: const Text('行动按钮文字'),
                hint: '如：了解更多',
                maxLength: 32,
              ),
              FTextField(
                key: const Key('ad-landing'),
                control: FTextFieldControl.managed(controller: _landing),
                label: const Text('落地页'),
                hint: 'https://example.com/page',
                keyboardType: TextInputType.url,
                maxLength: 2048,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        AppSection(
          title: '创意图片（${_mediaIds.length}/$maxAdCreatives）',
          child: Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              for (final mediaId in _mediaIds)
                _CreativeTile(
                  assetId: jsonInt64Id(mediaId),
                  onRemove: () => setState(
                    () => _mediaIds = [
                      for (final id in _mediaIds)
                        if (jsonInt64Id(id) != jsonInt64Id(mediaId)) id,
                    ],
                  ),
                ),
              if (_mediaIds.length < maxAdCreatives)
                FButton(
                  key: const Key('ad-add-creative'),
                  variant: FButtonVariant.outline,
                  mainAxisSize: MainAxisSize.min,
                  prefix: const Icon(FLucideIcons.imagePlus),
                  onPress: _uploading ? null : _addCreative,
                  child: Text(_uploading ? '上传中…' : '添加图片'),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space3),
        AppSection(
          title: '投放设置',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('市场', style: theme.typography.body.sm),
              const SizedBox(height: AppTheme.space2),
              Wrap(
                spacing: AppTheme.space2,
                runSpacing: AppTheme.space2,
                children: [
                  for (final market in widget.advertiser.markets)
                    AppChoiceButton(
                      key: Key('ad-market-$market'),
                      label: adMarketLabel(market),
                      selected: _market == market,
                      onPress: () => setState(() => _market = market),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.space3),
              Text('行业', style: theme.typography.body.sm),
              const SizedBox(height: AppTheme.space2),
              Wrap(
                spacing: AppTheme.space2,
                runSpacing: AppTheme.space2,
                children: [
                  for (final industry in catalog.industries)
                    AppChoiceButton(
                      key: Key('ad-industry-$industry'),
                      label: adIndustryLabel(industry),
                      selected: _industry == industry,
                      onPress: () => setState(() => _industry = industry),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.space2),
              Text(
                '酒精、博彩等行业在所有演示市场禁投；金融、医疗等需要目标市场的有效资质。',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        FButton(
          key: const Key('ad-submit'),
          onPress: _busy || _uploading ? null : _submit,
          child: Text(_busy ? '提交中…' : '提交审核'),
        ),
        const SizedBox(height: AppTheme.space6),
      ],
    );
  }
}

/// 广告写操作的错误提示；版本冲突保留输入，提示刷新（沿用帖子编辑）。
String adWriteErrorMessage(ApiException error) => switch (error.code) {
  ErrorCodes.contentVersionConflict => '广告已在别处更新，已保留你的输入，请刷新后再提交',
  ErrorCodes.advertiserRequired => '请先申请成为广告主并通过审核',
  ErrorCodes.adQualificationRequired => '该行业需要目标市场的有效资质',
  ErrorCodes.adLandingInvalid => '落地页地址不合规',
  ErrorCodes.adIndustryUnsupported => '该市场不支持此行业',
  ErrorCodes.adMediaInvalid => '图片无效或不属于你',
  ErrorCodes.idempotencyConflict => '重复提交的内容不一致，请重试',
  _ => '提交失败：${error.message}',
};

class _CreativeTile extends ConsumerWidget {
  final String assetId;
  final VoidCallback onRemove;

  const _CreativeTile({required this.assetId, required this.onRemove});

  static const size = 96.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final bytes = ref.watch(adAssetBytesProvider(assetId));
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: AppTheme.imageRadius,
            child: ColoredBox(
              color: theme.colors.muted,
              child: bytes.when(
                loading: () => const LoadingView(),
                error: (_, _) =>
                    const Center(child: Icon(FLucideIcons.circleAlert)),
                data: (data) => Image.memory(
                  data,
                  fit: BoxFit.cover,
                  semanticLabel: '创意图片 $assetId',
                ),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: FButton.icon(
              variant: FButtonVariant.secondary,
              size: FButtonSizeVariant.xs,
              semanticsLabel: '移除图片 $assetId',
              onPress: onRemove,
              child: const Icon(FLucideIcons.x),
            ),
          ),
        ],
      ),
    );
  }
}
