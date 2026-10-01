import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../sdk/data/gateway.dart';
import '../application/ads_providers.dart';
import '../data/ad_labels.dart';
import '../data/ads_repository.dart';

/// 解析 `YYYY-MM-DD` 为当日 UTC 结束时刻；格式错误或不晚于 [now] 时返回 null。
int? parseQualificationValidUntil(String raw, DateTime now) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day, 23, 59, 59);
  if (date.year != year || date.month != month || date.day != day) return null;
  if (!date.isAfter(now.toUtc())) return null;
  return date.millisecondsSinceEpoch;
}

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
  String? _key;
  String? _fingerprint;
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

  Future<void> _pickDocument() async {
    final file = await ref
        .read(adAssetPickerProvider)
        .pick(AdAssetKind.document);
    if (file == null || !mounted) return;
    final generation = ++_uploadGeneration;
    setState(() => _uploading = true);
    try {
      final asset = await ref
          .read(adsRepositoryProvider)
          .uploadAsset(
            kind: AdAssetKind.document,
            file: file,
            idempotencyKey: newIdempotencyKey(24),
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

  Future<void> _submit() async {
    final market = _market;
    final document = _document;
    final validUntil = parseQualificationValidUntil(
      _validUntil.text,
      widget.now(),
    );
    if (market == null) {
      showAppError(context, '请选择目标市场');
      return;
    }
    if (document == null) {
      showAppError(context, '请先上传资质证件');
      return;
    }
    if (validUntil == null) {
      showAppError(context, '有效期须为今天之后的日期，格式 YYYY-MM-DD');
      return;
    }
    final revision = widget.advertiser.revision;
    final fingerprint =
        '$revision|$market|$_industry|${document.assetId}|'
        '$validUntil';
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _key = newIdempotencyKey(24);
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(adsRepositoryProvider)
          .addQualification(
            AddQualificationReq(
              market: market,
              industry: _industry,
              documentAssetId: document.assetId,
              validUntilMs: validUntil,
              expectedRevision: revision,
              idempotencyKey: _key!,
            ),
          );
      _fingerprint = null;
      if (!mounted) return;
      // A fresh form prevents a second tap from filing the same document again.
      setState(() {
        _document = null;
        _documentName = '';
        _validUntil.clear();
      });
      showAppSuccess(context, '资质已提交，将与主体一起审核');
      ref.invalidate(myAdvertiserProvider);
    } on ApiException catch (error) {
      if (error.code != null) _fingerprint = null;
      if (!mounted) return;
      showAppError(
        context,
        error.code == ErrorCodes.contentVersionConflict
            ? '主体信息已更新，请刷新后再提交'
            : '提交失败：${error.message}',
      );
    } catch (error) {
      if (mounted) showAppError(context, '提交失败：${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    Widget choice(String label, bool selected, VoidCallback onPress, Key key) =>
        FButton(
          key: key,
          size: FButtonSizeVariant.sm,
          mainAxisSize: MainAxisSize.min,
          variant: selected ? FButtonVariant.secondary : FButtonVariant.outline,
          prefix: selected ? const Icon(FLucideIcons.check) : null,
          onPress: onPress,
          child: Text(label),
        );
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
                choice(
                  adMarketLabel(market),
                  _market == market,
                  () => setState(() => _market = market),
                  Key('qualification-market-$market'),
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
                choice(
                  adIndustryLabel(industry),
                  _industry == industry,
                  () => setState(() => _industry = industry),
                  Key('qualification-industry-$industry'),
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
