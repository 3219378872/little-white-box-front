import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/data/gateway.dart';
import '../data/ads_repository.dart';
import 'ads_dependencies.dart';
import 'ads_providers.dart';

/// 单条广告最多 3 张创意图（与 ad-rpc 一致）。
const maxAdCreatives = 3;

/// 表单未通过客户端校验；不会发出任何请求，[message] 直接展示给用户。
class AdFormInvalidException implements Exception {
  final String message;
  const AdFormInvalidException(this.message);

  @override
  String toString() => message;
}

// 广告写命令的幂等键：同一输入的网络重试复用同一键；输入变化换新键，
// 成功或收到业务错误码（服务端已给出结论）后作废，下次提交视为新命令。
class _IdempotentWrite {
  String? _key;
  String? _fingerprint;

  // 以 [fingerprint] 标识一次逻辑提交；[send] 收到本次应携带的幂等键。
  Future<T> run<T>(
    String fingerprint,
    Future<T> Function(String key) send,
  ) async {
    if (fingerprint != _fingerprint) {
      _fingerprint = fingerprint;
      _key = newIdempotencyKey(24);
    }
    try {
      final result = await send(_key!);
      _fingerprint = null;
      return result;
    } on ApiException catch (error) {
      // 无错误码是网络类失败，保留键供重试；有错误码说明服务端已处理该键。
      if (error.code != null) _fingerprint = null;
      rethrow;
    }
  }
}

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

/// 解析 `YYYY-MM-DD` 为当日 UTC 结束时刻；格式错误或不晚于 [now] 时返回 null。
int? parseQualificationValidUntil(String raw, DateTime now) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw.trim());
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day, 23, 59, 59);
  // DateTime 会把 2 月 30 日之类的日期滚动到下月，回读比对以拒绝不存在的日期。
  if (date.year != year || date.month != month || date.day != day) return null;
  if (!date.isAfter(now.toUtc())) return null;
  return date.millisecondsSinceEpoch;
}

/// 广告创建/编辑表单的输入快照，提交时由页面一次性收集。
class AdDraft {
  final String title;
  final String body;
  final String cta;
  final String landingUrl;
  final String market;
  final String industry;
  final List<Object> mediaIds;

  const AdDraft({
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUrl,
    required this.market,
    required this.industry,
    required this.mediaIds,
  });
}

/// 广告主主体与行业资质的写命令；成功后刷新本人广告主信息。
class AdvertiserCommands {
  final Ref _ref;
  final _apply = _IdempotentWrite();
  final _qualification = _IdempotentWrite();

  AdvertiserCommands(this._ref);

  AdsRepository get _repository => _ref.read(adsRepositoryProvider);

  /// 申请或修改广告主主体；修改会重新送审。
  Future<void> apply({
    required String name,
    required Set<String> markets,
    required AdvertiserItem? current,
  }) async {
    // 客户端预校验与服务端限制一致，失败时不发请求。
    final trimmed = name.trim();
    if (trimmed.runes.length < 2 || trimmed.runes.length > 64) {
      throw const AdFormInvalidException('主体名称须为 2～64 个字符');
    }
    if (markets.isEmpty) {
      throw const AdFormInvalidException('至少选择一个投放市场');
    }
    // 以当前主体版本作并发基线（未申请时为 0）；市场排序后参与指纹，勾选顺序不影响幂等。
    final revision = current?.revision ?? 0;
    final sortedMarkets = markets.toList()..sort();
    await _apply.run(
      '$revision|$trimmed|${sortedMarkets.join(',')}',
      (key) => _repository.applyAdvertiser(
        ApplyAdvertiserReq(
          name: trimmed,
          markets: sortedMarkets,
          expectedRevision: revision,
          idempotencyKey: key,
        ),
      ),
    );
    _refreshAdvertiser();
  }

  /// 选择资质证件文件；用户取消时返回 null。
  Future<XFile?> pickDocument() {
    return _ref.read(adAssetPickerProvider).pick(AdAssetKind.document);
  }

  /// 上传资质证件；[isCurrent] 为 false 时上传层丢弃迟到结果。
  Future<AdAssetResp> uploadDocument(
    XFile file, {
    required bool Function() isCurrent,
  }) {
    return _repository.uploadAsset(
      kind: AdAssetKind.document,
      file: file,
      idempotencyKey: newIdempotencyKey(24),
      isCurrent: isCurrent,
    );
  }

  /// 提交一份目标市场的行业资质；资质与主体一起作为一个对象审核。
  Future<void> addQualification({
    required AdvertiserItem advertiser,
    required String? market,
    required String industry,
    required AdAssetResp? document,
    required String validUntil,
    required DateTime now,
  }) async {
    // 依次校验市场、证件与有效期，给出首个缺失项。
    final validUntilMs = parseQualificationValidUntil(validUntil, now);
    if (market == null) {
      throw const AdFormInvalidException('请选择目标市场');
    }
    if (document == null) {
      throw const AdFormInvalidException('请先上传资质证件');
    }
    if (validUntilMs == null) {
      throw const AdFormInvalidException('有效期须为今天之后的日期，格式 YYYY-MM-DD');
    }
    final revision = advertiser.revision;
    await _qualification.run(
      '$revision|$market|$industry|${document.assetId}|$validUntilMs',
      (key) => _repository.addQualification(
        AddQualificationReq(
          market: market,
          industry: industry,
          documentAssetId: document.assetId,
          validUntilMs: validUntilMs,
          expectedRevision: revision,
          idempotencyKey: key,
        ),
      ),
    );
    _refreshAdvertiser();
  }

  // 页面已离开时 provider 已释放，无需也不能再刷新。
  void _refreshAdvertiser() {
    if (_ref.mounted) _ref.invalidate(myAdvertiserProvider);
  }
}

/// 广告编辑器的写命令：创意图上传与创建/更新送审（FX-110）。
class AdEditorCommands {
  final Ref _ref;
  final _save = _IdempotentWrite();

  AdEditorCommands(this._ref);

  AdsRepository get _repository => _ref.read(adsRepositoryProvider);

  /// 选择一张创意图；用户取消时返回 null。
  Future<XFile?> pickCreative() {
    return _ref.read(adAssetPickerProvider).pick(AdAssetKind.creative);
  }

  /// 上传创意图；[isCurrent] 为 false 时上传层丢弃迟到结果。
  Future<AdAssetResp> uploadCreative(
    XFile file, {
    required bool Function() isCurrent,
  }) {
    return _repository.uploadAsset(
      kind: AdAssetKind.creative,
      file: file,
      idempotencyKey: newIdempotencyKey(24),
      isCurrent: isCurrent,
    );
  }

  /// 创建新广告或基于 [existing] 的版本提交修改；成功后刷新该广告详情并返回服务端结果。
  Future<AdItem> save(AdDraft draft, {AdItem? existing}) async {
    // 客户端校验失败时不发请求。
    final invalid = validateAdDraft(
      title: draft.title,
      body: draft.body,
      cta: draft.cta,
      landingUrl: draft.landingUrl,
    );
    if (invalid != null) throw AdFormInvalidException(invalid);
    final title = draft.title.trim();
    final body = draft.body.trim();
    final cta = draft.cta.trim();
    final landingUrl = draft.landingUrl.trim();
    // 指纹包含基线版本，版本变化后的重新提交是新命令。
    final fingerprint = [
      existing?.revision ?? 0,
      title,
      body,
      cta,
      landingUrl,
      draft.market,
      draft.industry,
      draft.mediaIds.map(jsonInt64Id).join(','),
    ].join('|');
    final saved = await _save.run(fingerprint, (key) {
      if (existing == null) {
        return _repository.createAd(
          CreateAdReq(
            title: title,
            body: body,
            cta: cta,
            landingUrl: landingUrl,
            mediaIds: draft.mediaIds,
            market: draft.market,
            industry: draft.industry,
            startMs: 0,
            endMs: 0,
            idempotencyKey: key,
          ),
        );
      }
      // 编辑带 expectedRevision，投放时间沿用原广告。
      return _repository.updateAd(
        existing.adId,
        UpdateAdReq(
          adId: existing.adId,
          expectedRevision: existing.revision,
          title: title,
          body: body,
          cta: cta,
          landingUrl: landingUrl,
          mediaIds: draft.mediaIds,
          market: draft.market,
          industry: draft.industry,
          startMs: existing.startMs,
          endMs: existing.endMs,
          idempotencyKey: key,
        ),
      );
    });
    // 详情页在编辑器关闭或跳转后读取最新版本与审核状态。
    if (_ref.mounted) {
      _ref.invalidate(adDetailProvider(jsonInt64Id(saved.adId)));
    }
    return saved;
  }
}

/// 广告申诉命令：每个被拒或被下线的版本可申诉一次，复审结论为最终结论（FX-110、ADS-014）。
class AdAppealCommands {
  final Ref _ref;
  final String adId;
  final _appeal = _IdempotentWrite();

  AdAppealCommands(this._ref, this.adId);

  /// 发起申诉；成功或服务端判定不可申诉时都刷新详情，让按钮状态与服务端一致。
  Future<void> appeal() async {
    try {
      await _appeal.run(
        adId,
        (key) => _ref.read(adsRepositoryProvider).appealAd(adId, key),
      );
      _refreshDetail();
    } on ApiException catch (error) {
      if (error.code == ErrorCodes.adAppealNotAllowed) _refreshDetail();
      rethrow;
    }
  }

  // 页面已离开时 provider 已释放，跳过刷新。
  void _refreshDetail() {
    if (_ref.mounted) _ref.invalidate(adDetailProvider(adId));
  }
}

/// 主体与资质页面共用一组命令；页面离开后释放，未完成的幂等键随之作废。
final advertiserCommandsProvider = Provider.autoDispose<AdvertiserCommands>(
  AdvertiserCommands.new,
);

/// 每个编辑器（按广告 ID，新建为 null）一组命令，保证重试只复用同一广告的幂等键。
final adEditorCommandsProvider = Provider.autoDispose
    .family<AdEditorCommands, String?>((ref, adId) => AdEditorCommands(ref));

/// 按广告 ID 隔离申诉命令。
final adAppealCommandsProvider = Provider.autoDispose
    .family<AdAppealCommands, String>(AdAppealCommands.new);

/// 读取广告素材原图字节，供编辑器预览已上传的创意图。
final adAssetBytesProvider = FutureProvider.autoDispose
    .family<Uint8List, String>((ref, assetId) {
      return ref.read(adsRepositoryProvider).readAsset(assetId);
    });

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

/// 申诉的错误提示（ADS-014）。
String adAppealErrorMessage(ApiException error) => switch (error.code) {
  ErrorCodes.adAppealNotAllowed => '当前版本不可申诉（每个版本只能申诉一次）',
  ErrorCodes.idempotencyConflict => '重复提交的内容不一致，请重试',
  _ => '申诉失败：${error.message}',
};

/// 主体申请/修改的错误提示。
String advertiserWriteErrorMessage(ApiException error) => switch (error.code) {
  ErrorCodes.contentVersionConflict => '主体信息已在别处更新，请刷新后再提交',
  ErrorCodes.advertiserExists => '你已经是广告主，请刷新后修改',
  _ => '提交失败：${error.message}',
};

/// 资质提交的错误提示。
String qualificationWriteErrorMessage(ApiException error) =>
    error.code == ErrorCodes.contentVersionConflict
    ? '主体信息已更新，请刷新后再提交'
    : '提交失败：${error.message}';
