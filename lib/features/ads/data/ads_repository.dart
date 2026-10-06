import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_adapter.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/image_mime.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 私有素材类型：广告创意图片或资质证件。
enum AdAssetKind {
  creative('creative'),
  document('document');

  const AdAssetKind(this.path);

  /// 上传路径 `/api/v2/ads/assets/{kind}` 中的类型段。
  final String path;
}

/// 与 ad-rpc 私有存储上限一致（2 MiB）。
const maxAdAssetBytes = 2 * 1024 * 1024;

/// 广告主控制台与推荐流隐藏、举报所用的 Gateway 接口（FX-101、FX-110）。
class AdsRepository {
  // 隐藏与举报按客户端会话归属，匿名用户也能生效。
  final ClientIdentityStore _identityStore;

  const AdsRepository({required ClientIdentityStore identityStore})
    : _identityStore = identityStore;

  /// 读取本人广告主主体（GET /api/v2/ads/advertiser）；尚未申请时返回 null。
  Future<AdvertiserItem?> getMyAdvertiser() async {
    final resp = await apiCall<AdvertiserResp>(
      (ok, fail, eventually) =>
          gw.getMyAdvertiser(ok: ok, fail: fail, eventually: eventually),
    );
    return resp.found ? resp.advertiser : null;
  }

  /// 申请或修改广告主主体（PUT /api/v2/ads/advertiser），返回服务端最新主体。
  Future<AdvertiserItem> applyAdvertiser(ApplyAdvertiserReq req) async {
    final resp = await apiCall<AdvertiserResp>(
      (ok, fail, eventually) =>
          gw.applyAdvertiser(req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAdvertiser(resp);
  }

  /// 为主体追加一份行业资质（POST /api/v2/ads/advertiser/qualifications），返回最新主体。
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

  /// 政策码、可选市场与行业目录（GET /api/v2/ads/policies）。
  Future<ListAdPoliciesResp> listPolicies() {
    return apiCall<ListAdPoliciesResp>(
      (ok, fail, eventually) =>
          gw.listAdPolicies(ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 本人广告列表（GET /api/v2/ads），按 [cursor] 游标分页。
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

  /// 单条广告详情（GET /api/v2/ads/{adId}）。
  Future<AdItem> getAd(Object adId) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.getAd(adId, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  /// 创建广告（POST /api/v2/ads），返回服务端保存的版本。
  Future<AdItem> createAd(CreateAdReq req) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.createAd(req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  /// 按 `expectedRevision` 修改广告（PUT /api/v2/ads/{adId}），返回新版本。
  Future<AdItem> updateAd(Object adId, UpdateAdReq req) async {
    final resp = await apiCall<AdResp>(
      (ok, fail, eventually) =>
          gw.updateAd(adId, req, ok: ok, fail: fail, eventually: eventually),
    );
    return _requireAd(resp);
  }

  /// 隐藏推荐流中的广告；匿名用户只按当前会话隐藏。
  /// 对应 POST /api/v2/ads/{adId}/hide；`ok` 为 false 时按失败抛出。
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
  /// 对应 POST /api/v2/ads/{adId}/report。
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
  /// 对应 POST /api/v2/ads/{adId}/appeal；[idempotencyKey] 由调用方在重试间复用。
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
  /// 对应 POST /api/v2/ads/assets/{kind}；响应缺少正数素材 ID 时视为格式错误。
  Future<AdAssetResp> uploadAsset({
    required AdAssetKind kind,
    required XFile file,
    required String idempotencyKey,
    bool Function()? isCurrent,
  }) async {
    // 本地先拦截空文件与超限文件，不发起注定被拒的上传。
    final length = await file.length();
    if (length <= 0 || length > maxAdAssetBytes) {
      throw const ApiException('文件须为 1 字节至 2 MiB');
    }
    // 读取文件头，供无扩展名且选择器未声明类型时识别格式。
    // openRead 的 end 不能超过文件长度，小文件只读到末尾。
    final head = await _readHead(file, min(length, imageMimeSniffLength));
    return apiPostMultipart<AdAssetResp>(
      path: gw.uploadAdAssetPath(kind.path),
      fieldName: 'file',
      filename: file.name,
      openRead: file.openRead,
      length: length,
      fields: {'idempotencyKey': idempotencyKey},
      isCurrent: isCurrent,
      contentType: adAssetMimeType(file.name, file.mimeType, head),
      // 后续创建广告与提交资质只引用素材 ID，缺失即无法继续。
      decodeData: (data) {
        final asset = AdAssetResp.fromJson(data);
        if (!jsonInt64IsPositive(asset.assetId)) {
          throw const ApiException('上传响应缺少素材标识');
        }
        return asset;
      },
    );
  }

  /// 本人私有素材的字节内容，用于编辑时预览。
  /// 对应 GET /api/v2/ads/assets/{assetId}，内容以 base64 返回后在此解码。
  Future<Uint8List> readAsset(Object assetId) async {
    final resp = await apiCall<AdAssetContentResp>(
      (ok, fail, eventually) =>
          gw.getAdAsset(assetId, ok: ok, fail: fail, eventually: eventually),
    );
    return base64Decode(resp.contentBase64);
  }

  // 只读取前 [length] 字节，避免为识别类型把整份素材读入内存。
  static Future<List<int>> _readHead(XFile file, int length) async {
    final head = <int>[];
    await for (final chunk in file.openRead(0, length)) {
      head.addAll(chunk);
    }
    return head;
  }

  // 写主体接口必须带回主体；缺失视为服务端异常，而不是“尚未申请”。
  static AdvertiserItem _requireAdvertiser(AdvertiserResp resp) {
    final advertiser = resp.advertiser;
    if (!resp.found || advertiser == null) {
      throw const ApiException('广告主信息缺失');
    }
    return advertiser;
  }

  // 广告响应须带正数广告 ID，否则视为广告缺失。
  static AdItem _requireAd(AdResp resp) {
    final ad = resp.ad;
    if (!jsonInt64IsPositive(ad.adId)) {
      throw const ApiException('广告信息缺失');
    }
    return ad;
  }
}

/// 推断素材上传声明的 MIME；服务端仍以内容嗅探为准。
///
/// 依次采用选择器声明的类型、PDF（扩展名或 `%PDF` 文件头）、共享的图片识别，
/// 图片识别不出时回退 `image/jpeg`。
String adAssetMimeType(String filename, String? declared, List<int> head) {
  if (declared != null && declared.isNotEmpty) return declared;
  if (filename.toLowerCase().split('.').last == 'pdf' || _hasPdfHeader(head)) {
    return 'application/pdf';
  }
  return inferImageMime(filename, head);
}

// PDF 文件以 `%PDF` 开头。
bool _hasPdfHeader(List<int> head) =>
    head.length >= 4 &&
    head[0] == 0x25 &&
    head[1] == 0x50 &&
    head[2] == 0x44 &&
    head[3] == 0x46;

/// 选择广告创意图片或资质证件。
class AdAssetPicker {
  const AdAssetPicker();

  /// 创意图从相册选取；证件走文件选择器，允许常见图片与 PDF。用户取消时返回 null。
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
