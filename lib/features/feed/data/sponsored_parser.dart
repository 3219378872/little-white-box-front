import '../../../core/api/json_int64.dart';
import 'feed_models.dart';

/// 逐槽容错解析广告槽位（FX-103、FQ-011）。
///
/// 与 `items` 的严格解析相互独立：单个槽位格式错误只丢弃该槽，永不抛出。字段缺失、
/// 标识不是 `sponsored`、落地页不是 https 或域名与地址不一致时都视为格式错误，避免展示
/// 无法标识或会误导的广告。
List<SponsoredSlot> parseSponsoredSlots(
  Object? raw, {
  required String requestId,
  required String scene,
}) {
  // 字段缺失表示本页没有广告；类型不对时整体丢弃。
  if (raw is! List) return const [];
  final slots = <SponsoredSlot>[];
  final seen = <String>{};
  for (final item in raw) {
    final slot = _parseSlot(item, requestId: requestId, scene: scene);
    // 同一页内重复的 slotId 只保留第一个。
    if (slot == null || !seen.add(slot.slotId)) continue;
    slots.add(slot);
  }
  return slots;
}

// 解析单个槽位：slotId 非空、afterPosition 为正整数且 ad 是对象，否则丢弃。
SponsoredSlot? _parseSlot(
  Object? raw, {
  required String requestId,
  required String scene,
}) {
  if (raw is! Map) return null;
  final slotId = _text(raw['slotId']);
  final afterPosition = raw['afterPosition'];
  final ad = raw['ad'];
  if (slotId.isEmpty ||
      afterPosition is! int ||
      afterPosition < 1 ||
      ad is! Map) {
    return null;
  }
  final parsedAd = _parseAd(ad);
  if (parsedAd == null) return null;
  return SponsoredSlot(
    slotId: slotId,
    afterPosition: afterPosition,
    ad: parsedAd,
    context: FeedRecommendationContext(
      requestId: requestId,
      scene: scene,
      position: afterPosition,
      recallSource: 'sponsored',
      modelVersion: '',
      experimentId: '',
    ),
  );
}

// 解析广告主体：必填标识与文案齐全、显式标为 sponsored、落地页为 https 且主机与声明域名一致。
SponsoredAd? _parseAd(Map<dynamic, dynamic> ad) {
  final adId = ad['adId'];
  final revision = ad['revision'];
  final advertiserName = _text(ad['advertiserName']);
  final title = _text(ad['title']);
  final landingDomain = _text(ad['landingDomain']).toLowerCase();
  final landing = Uri.tryParse(_text(ad['landingUrl']));
  if (!jsonInt64IsPositive(adId) ||
      revision is! int ||
      revision < 1 ||
      advertiserName.isEmpty ||
      title.isEmpty ||
      ad['disclosure'] != 'sponsored' ||
      landing == null ||
      landing.scheme != 'https' ||
      landing.host.isEmpty ||
      landing.userInfo.isNotEmpty ||
      landing.host.toLowerCase() != landingDomain) {
    return null;
  }
  // 图片与「为什么看到」是可选字段：非法图片地址被过滤，缺失时使用空值。
  final images = ad['images'];
  final why = ad['why'];
  return SponsoredAd(
    adId: adId!,
    revision: revision,
    advertiserName: advertiserName,
    title: title,
    body: _text(ad['body']),
    cta: _text(ad['cta']),
    landingUri: landing,
    landingDomain: landingDomain,
    images: images is List
        ? images.whereType<String>().where(_isWebUrl).toList()
        : const [],
    why: why is Map
        ? SponsoredWhy(
            market: _text(why['market']),
            scene: _text(why['scene']),
            personalized: why['personalized'] == true,
          )
        : const SponsoredWhy(),
  );
}

// 只接受站内相对路径或带主机的 http(s) 地址，拒绝带用户信息的 URL。
bool _isWebUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty) return false;
  if (!uri.hasScheme) return uri.path.startsWith('/');
  return {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty;
}

// 只接受字符串字段并去首尾空白，其他类型视为缺失。
String _text(Object? value) => value is String ? value.trim() : '';
