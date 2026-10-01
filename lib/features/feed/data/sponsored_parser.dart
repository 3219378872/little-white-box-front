import '../../../core/api/json_int64.dart';
import 'feed_models.dart';

/// 推荐流 `sponsored` 的逐槽解析结果。
class SponsoredParseResult {
  final List<SponsoredSlot> slots;
  final int dropped;

  const SponsoredParseResult(this.slots, this.dropped);
}

/// 逐槽容错解析广告槽位（FX-103、FQ-011）。
///
/// 与 `items` 的严格解析相互独立：单个槽位格式错误只丢弃该槽并计数，永不抛出。字段缺失、
/// 标识不是 `sponsored`、落地页不是 https 或域名与地址不一致时都视为格式错误，避免展示
/// 无法标识或会误导的广告。
SponsoredParseResult parseSponsoredSlots(
  Object? raw, {
  required String requestId,
  required String scene,
}) {
  if (raw == null) return const SponsoredParseResult([], 0);
  if (raw is! List) return const SponsoredParseResult([], 1);
  final slots = <SponsoredSlot>[];
  final seen = <String>{};
  var dropped = 0;
  for (final item in raw) {
    final slot = _parseSlot(item, requestId: requestId, scene: scene);
    if (slot == null || !seen.add(slot.slotId)) {
      dropped++;
      continue;
    }
    slots.add(slot);
  }
  return SponsoredParseResult(slots, dropped);
}

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

bool _isWebUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.userInfo.isNotEmpty) return false;
  if (!uri.hasScheme) return uri.path.startsWith('/');
  return {'http', 'https'}.contains(uri.scheme) && uri.host.isNotEmpty;
}

String _text(Object? value) => value is String ? value.trim() : '';
