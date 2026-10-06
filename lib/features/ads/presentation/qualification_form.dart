import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_choice_button.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ad_commands.dart';
import 'ad_labels.dart';

/// 上传证件并提交一份目标市场的行业资质（FX-110）。
class QualificationForm extends ConsumerStatefulWidget {
  final AdvertiserItem advertiser;
  final DateTime Function() now;

  const QualificationForm({
    super.key,
    required this.advertiser,
    this.now = DateTime.now,
  });

  @override
  ConsumerState<QualificationForm> createState() => _QualificationFormState();
}

class _QualificationFormState extends ConsumerState<QualificationForm> {
  final _validUntil = TextEditingController();
  String? _market;
  String _industry = qualificationIndustries.first;
  AdAssetResp? _document;
  String _documentName = '';
  bool _uploading = false;
  bool _busy = false;
  int _uploadGeneration = 0;

  @override
  void initState() {
    super.initState();
    final markets = widget.advertiser.markets;
    _market = markets.isEmpty ? null : markets.first;
  }

  @override
  void didUpdateWidget(covariant QualificationForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final markets = widget.advertiser.markets;
    if (!markets.contains(_market)) {
      _market = markets.isEmpty ? null : markets.first;
    }
  }

  @override
  void dispose() {
    _uploadGeneration++;
    _validUntil.dispose();
    super.dispose();
  }

  AdvertiserCommands get _commands => ref.read(advertiserCommandsProvider);

  // 选择并上传证件；离开页面或再次选择后，旧上传结果不再写回表单。
  Future<void> _pickDocument() async {
    final file = await _commands.pickDocument();
    if (file == null || !mounted) return;
    final generation = ++_uploadGeneration;
    setState(() => _uploading = true);
    try {
      final asset = await _commands.uploadDocument(
        file,
        isCurrent: () => mounted && generation == _uploadGeneration,
      );
      if (!mounted || generation != _uploadGeneration) return;
      setState(() {
        _document = asset;
        _documentName = file.name;
      });
    } catch (error) {
      if (mounted) {
        showAppError(context, '证件上传失败：${friendlyErrorMessage(error)}');
      }
    } finally {
      if (mounted && generation == _uploadGeneration) {
        setState(() => _uploading = false);
      }
    }
  }

  // 校验、幂等键与刷新由 AdvertiserCommands 负责；页面只管表单、忙碌态与提示。
  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _commands.addQualification(
        advertiser: widget.advertiser,
        market: _market,
        industry: _industry,
        document: _document,
        validUntil: _validUntil.text,
        now: widget.now(),
      );
      if (!mounted) return;
      // A fresh form prevents a second tap from filing the same document again.
      setState(() {
        _document = null;
        _documentName = '';
        _validUntil.clear();
      });
      showAppSuccess(context, '资质已提交，将与主体一起审核');
    } on AdFormInvalidException catch (error) {
      if (mounted) showAppError(context, error.message);
    } on ApiException catch (error) {
      if (!mounted) return;
      showAppError(context, qualificationWriteErrorMessage(error));
    } catch (error) {
      if (mounted) showAppError(context, '提交失败：${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // 保持命令实例存活，失败重试才能复用同一幂等键。
    ref.watch(advertiserCommandsProvider);
    return AppSection(
      title: '提交行业资质',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('目标市场', style: theme.typography.body.sm),
          const SizedBox(height: AppTheme.space2),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              for (final market in widget.advertiser.markets)
                AppChoiceButton(
                  key: Key('qualification-market-$market'),
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
              for (final industry in qualificationIndustries)
                AppChoiceButton(
                  key: Key('qualification-industry-$industry'),
                  label: adIndustryLabel(industry),
                  selected: _industry == industry,
                  onPress: () => setState(() => _industry = industry),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.space3),
          FTextField(
            key: const Key('qualification-valid-until'),
            control: FTextFieldControl.managed(controller: _validUntil),
            label: const Text('有效期至'),
            hint: 'YYYY-MM-DD',
            maxLength: 10,
          ),
          const SizedBox(height: AppTheme.space3),
          Row(
            children: [
              FButton(
                key: const Key('qualification-upload'),
                variant: FButtonVariant.outline,
                mainAxisSize: MainAxisSize.min,
                prefix: const Icon(FLucideIcons.upload),
                onPress: _uploading ? null : _pickDocument,
                child: Text(_uploading ? '上传中…' : '上传证件'),
              ),
              const SizedBox(width: AppTheme.space2),
              Expanded(
                child: Text(
                  _document == null
                      ? 'JPG、PNG、WebP 或 PDF，不超过 2 MiB'
                      : _documentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.space2),
          Text(
            '证件只保存在私有存储，仅审核人员可经鉴权查看。',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
          const SizedBox(height: AppTheme.space3),
          FButton(
            key: const Key('qualification-submit'),
            onPress: _busy || _uploading ? null : _submit,
            child: Text(_busy ? '提交中…' : '提交资质'),
          ),
        ],
      ),
    );
  }
}
