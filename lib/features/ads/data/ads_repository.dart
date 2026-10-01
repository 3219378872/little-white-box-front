import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 私有素材类型：广告创意图片或资质证件。
enum AdAssetKind {
  creative('creative'),
  document('document');

  const AdAssetKind(this.path);
  final String path;
}

/// 与 ad-rpc 私有存储上限一致（2 MiB）。
const maxAdAssetBytes = 2 * 1024 * 1024;

/// 广告主控制台与推荐流隐藏、举报所用的 Gateway 接口（FX-101、FX-110）。
class AdsRepository {
  final ClientIdentityStore _identityStore;

  const AdsRepository({required ClientIdentityStore identityStore})
    : _identityStore = identityStore;

  Future<AdvertiserItem?> getMyAdvertiser() async {
    final resp = await apiCall<AdvertiserResp>(
      (ok, fail, eventually) =>
          gw.getMyAdvertiser(ok: ok, fail: fail, eventually: eventually),
    );
    return resp.found ? resp.advertiser : null;
  }

  Future<AdvertiserItem> applyAdvertiser(ApplyAdvertiserReq req) async {
    final resp = await apiCall<AdvertiserResp>(
      (ok, fail, eventually) =>
          gw.applyAdvertiser(req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAdvertiser(resp);
  }

  Future<AdvertiserItem> addQualification(AddQualificationReq req) async {
    final resp = await apiCall<AdvertiserResp>(
      (ok, fail, eventually) => gw.addAdQualification(
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return _requireAdvertiser(resp);
  }

  Future<ListAdPoliciesResp> listPolicies() {
    return apiCall<ListAdPoliciesResp>(
      (ok, fail, eventually) =>
          gw.listAdPolicies(ok: ok, fail: fail, eventually: eventually),
    );
  }

  Future<ListAdsResp> listAds({String cursor = '', int pageSize = 20}) {
    return apiCall<ListAdsResp>(
      (ok, fail, eventually) => gw.listAds(
        request: ListAdsReq(cursor: cursor, pageSize: pageSize),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  Future<AdItem> getAd(Object adId) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.getAd(adId, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  Future<AdItem> createAd(CreateAdReq req) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.createAd(req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  Future<AdItem> updateAd(Object adId, UpdateAdReq req) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.updateAd(adId, req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  /// 隐藏推荐流中的广告；匿名用户只按当前会话隐藏。
  Future<void> hideAd(Object adId) async {
    final identity = await _identityStore.loadOrCreate();
    final resp = await apiCall<AdActionResp>(
      (ok, fail, eventually) => gw.hideAd(
        adId,
        HideAdReq(adId: adId, sessionId: identity.sessionId),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    if (!resp.ok) throw const ApiException('隐藏失败');
  }

  /// 举报推荐流中的广告（ADS-030）；服务端同时对举报人隐藏该广告，匿名用户只在当前会话内。
  /// 返回是否新计入（同一身份重复举报为 false）。
  Future<bool> reportAd(Object adId, String reason) async {
    final identity = await _identityStore.loadOrCreate();
    final resp = await apiCall<ReportAdResp>(
      (ok, fail, eventually) => gw.reportAd(
        adId,
        ReportAdReq(adId: adId, sessionId: identity.sessionId, reason: reason),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return resp.counted;
  }

  /// 对被拒或被下线的版本申诉，每个版本一次（ADS-014）。
  Future<AdItem> appealAd(Object adId, String idempotencyKey) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) => gw.appealAd(
        adId,
        AppealAdReq(adId: adId, idempotencyKey: idempotencyKey),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return _requireAd(resp);
  }

  /// 以 multipart 上传私有素材，只返回资产 ID 与校验信息，不返回公开地址。
  Future<AdAssetResp> uploadAsset({
    required AdAssetKind kind,
    required XFile file,
    required String idempotencyKey,
    bool Function()? isCurrent,
  }) async {
    final length = await file.length();
    if (length <= 0 || length > maxAdAssetBytes) {
      throw const ApiException('文件须为 1 字节至 2 MiB');
    }
    return apiPostMultipart<AdAssetResp>(
      path: gw.uploadAdAssetPath(kind.path),
      fieldName: 'file',
      filename: file.name,
      openRead: file.openRead,
      length: length,
      fields: {'idempotencyKey': idempotencyKey},
      isCurrent: isCurrent,
      contentType: adAssetMimeType(file.name, file.mimeType),
      decodeData: (data) {
        final asset = AdAssetResp.fromJson(data);
        if (!jsonInt64IsPositive(asset.assetId)) {
          throw const FormatException('上传响应缺少素材标识');
        }
        return asset;
      },
    );
  }

  /// 本人私有素材的字节内容，用于编辑时预览。
  Future<Uint8List> readAsset(Object assetId) async {
    final resp = await apiCall<AdAssetContentResp>(
      (ok, fail, eventually) =>
          gw.getAdAsset(assetId, ok: ok, fail: fail, eventually: eventually),
    );
    return base64Decode(resp.contentBase64);
  }

  static AdvertiserItem _requireAdvertiser(AdvertiserResp resp) {
    final advertiser = resp.advertiser;
    if (!resp.found || advertiser == null) {
      throw const ApiException('广告主信息缺失');
    }
    return advertiser;
  }

  static AdItem _requireAd(AdResp resp) {
    final ad = resp.ad;
    if (!jsonInt64IsPositive(ad.adId)) {
      throw const ApiException('广告信息缺失');
    }
    return ad;
  }
}

/// 按扩展名推断素材 MIME；服务端仍以内容嗅探为准。
String adAssetMimeType(String filename, String? declared) {
  if (declared != null && declared.isNotEmpty) return declared;
  return switch (filename.toLowerCase().split('.').last) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => 'image/jpeg',
  };
}

/// 选择广告创意图片或资质证件。
class AdAssetPicker {
  const AdAssetPicker();

  Future<XFile?> pick(AdAssetKind kind) {
    return switch (kind) {
      AdAssetKind.creative => ImagePicker().pickImage(
        source: ImageSource.gallery,
      ),
      AdAssetKind.document => openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: '证件 JPG / PNG / WebP / PDF',
            extensions: ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
            mimeTypes: [
              'image/jpeg',
              'image/png',
              'image/webp',
              'application/pdf',
            ],
            uniformTypeIdentifiers: [
              'public.jpeg',
              'public.png',
              'org.webmproject.webp',
              'com.adobe.pdf',
            ],
          ),
        ],
      ),
    };
  }
}

final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(identityStore: ref.read(clientIdentityStoreProvider));
});

final adAssetPickerProvider = Provider<AdAssetPicker>(
  (ref) => const AdAssetPicker(),
);
