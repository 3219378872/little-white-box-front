import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_choice_button.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ad_commands.dart';
import '../application/ads_providers.dart';
import 'ad_labels.dart';
import '../../../core/router/app_routes.dart';

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
                context.canPop() ? context.pop() : context.go(AppRoutes.ads),
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

  AdEditorCommands get _commands =>
      ref.read(adEditorCommandsProvider(_existingId));

  String? get _existingId =>
      _existing == null ? null : jsonInt64Id(_existing!.adId);

  // 选择并上传一张创意图；离开页面或再次选择后，旧上传结果不再写回表单。
  Future<void> _addCreative() async {
    if (_mediaIds.length >= maxAdCreatives) return;
    final file = await _commands.pickCreative();
    if (file == null || !mounted) return;
    final generation = ++_uploadGeneration;
    setState(() => _uploading = true);
    try {
      final asset = await _commands.uploadCreative(
        file,
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

  // 校验、幂等键与详情刷新由 AdEditorCommands 负责；页面只管忙碌态、提示与导航。
  Future<void> _submit() async {
    final existing = _existing;
    final draft = AdDraft(
      title: _title.text,
      body: _body.text,
      cta: _cta.text,
      landingUrl: _landing.text,
      market: _market,
      industry: _industry,
      mediaIds: _mediaIds,
    );
    setState(() => _busy = true);
    try {
      final saved = await _commands.save(draft, existing: existing);
      if (!mounted) return;
      showAppSuccess(context, '已提交审核');
      final id = jsonInt64Id(saved.adId);
      if (existing != null && context.canPop()) {
        // The detail page below refreshes itself when the editor closes.
        context.pop();
      } else {
        context.pushReplacement(AppRoutes.adDetail(id));
      }
    } on AdFormInvalidException catch (error) {
      if (mounted) showAppError(context, error.message);
    } on ApiException catch (error) {
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
    final catalog = resolveAdPolicyCatalog(
      ref.watch(adPolicyCatalogProvider).value,
    );
    // 保持本编辑器的命令实例存活，失败重试才能复用同一幂等键。
    ref.watch(adEditorCommandsProvider(_existingId));
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
