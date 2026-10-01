import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/features/ads/application/ads_providers.dart';
import 'package:xiaobaihe_app/features/ads/data/ad_labels.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ad_detail_page.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ad_editor_page.dart';
import 'package:xiaobaihe_app/features/ads/presentation/qualification_form.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

AdContentItem content({String title = 'T', String landing = 'https://a.com'}) =>
    AdContentItem.fromJson({
      'title': title,
      'body': 'B',
      'cta': 'Go',
      'landingUrl': landing,
      'market': 'US',
      'industry': 'GENERAL',
      'media': [
        {'mediaId': 5, 'sha256': 'abcdef1234', 'publicUrl': ''},
      ],
    });

void main() {
  test('policy codes map to Chinese and unknown codes stay raw', () {
    expect(adPolicyLabel('LANDING.MISMATCH'), '落地页与广告内容、语言或目标市场不一致');
    expect(adPolicyLabel('FUTURE.CODE'), 'FUTURE.CODE');
    expect(AdPolicyCatalog.fallback.titleOf('CONTENT.IP'), '知识产权侵权');
    expect(AdPolicyCatalog.fallback.titleOf('X.Y'), 'X.Y');
    expect(adPauseReasonLabel('qa'), '质检复审判定违规');
    expect(adPauseReasonLabel('rescan'), '政策回扫判定疑似违规');
    expect(adPauseReasonLabel('report'), '用户举报经复审成立');
    expect(reviewEscalationLabel('rescan-violation'), contains('已暂停投放'));
    expect(reviewEscalationLabel('future-reason'), 'future-reason');
    expect(reviewPurposeHint('initial'), isNull);
    expect(adReportReasons.map((r) => r.$1), contains('scam'));
    expect(adPauseReasonLabel('INDUSTRY.QUALIFICATION'), '缺少目标市场要求的行业资质');
    expect(adReviewStatusLabel('pending_review'), '审核中');
    expect(adServingStatusLabel('paused'), '已暂停');
  });

  test('ad drafts follow the backend length and https rules', () {
    String? check({
      String title = 'T',
      String body = 'B',
      String cta = 'Go',
      String landing = 'https://shop.example.com/x',
    }) => validateAdDraft(
      title: title,
      body: body,
      cta: cta,
      landingUrl: landing,
    );

    expect(check(), isNull);
    expect(check(title: ' '), contains('标题'));
    expect(check(title: 'x' * 101), contains('标题'));
    expect(check(body: 'x' * 501), contains('正文'));
    expect(check(cta: 'x' * 33), contains('行动按钮'));
    expect(check(landing: 'http://shop.example.com'), contains('https'));
    expect(check(landing: 'https://u@shop.example.com'), contains('https'));
    expect(check(landing: 'https://${'a' * 2048}.com'), contains('https'));
  });

  test('qualification dates must be valid and in the future', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    expect(
      parseQualificationValidUntil('2027-02-28', now),
      DateTime.utc(2027, 2, 28, 23, 59, 59).millisecondsSinceEpoch,
    );
    expect(parseQualificationValidUntil('2027-02-30', now), isNull);
    expect(parseQualificationValidUntil('2026-09-30', now), isNull);
    expect(parseQualificationValidUntil('2027/01/01', now), isNull);
  });

  test('diff lists only the fields that changed since approval', () {
    final diffs = diffAdContent(
      content(title: 'New', landing: 'https://b.com'),
      content(),
    );
    expect(diffs.map((d) => d.field), ['标题', '落地页']);
    expect(diffs.first.approved, 'T');
    expect(diffAdContent(content(), content()), isEmpty);
  });

  test('asset mime falls back to the file extension', () {
    expect(adAssetMimeType('a.PDF', null), 'application/pdf');
    expect(adAssetMimeType('a.webp', ''), 'image/webp');
    expect(adAssetMimeType('a.bin', 'image/png'), 'image/png');
  });

  test(
    'ads list pages by cursor, dedupes, and keeps rows on failure',
    () async {
      final repository = _PagedAdsRepository([
        ListAdsResp(ads: [ad(1), ad(2)], nextCursor: 'c1', hasMore: true),
        ListAdsResp(ads: [ad(2), ad(3)], nextCursor: '', hasMore: false),
      ]);
      final notifier = AdsListNotifier(repository, loadImmediately: false);

      await notifier.refresh();
      await notifier.loadMore();
      await notifier.loadMore();

      expect(notifier.state.ads.map((item) => item.adId), [1, 2, 3]);
      expect(notifier.state.hasMore, isFalse);
      expect(repository.cursors, ['', 'c1']);

      final failing = _PagedAdsRepository([
        ListAdsResp(ads: [ad(1)], nextCursor: 'c1', hasMore: true),
      ]);
      final second = AdsListNotifier(failing, loadImmediately: false);
      await second.refresh();
      await second.loadMore();
      expect(second.state.ads.map((item) => item.adId), [1]);
      expect(second.state.error, isNotNull);
      expect(second.state.hasMore, isTrue);
    },
  );
}

AdItem ad(int id) => AdItem.fromJson({
  'adId': id,
  'latest': {'title': 'Ad $id'},
});

class _PagedAdsRepository extends AdsRepository {
  final List<ListAdsResp> pages;
  final List<String> cursors = [];

  _PagedAdsRepository(this.pages) : super(identityStore: ClientIdentityStore());

  @override
  Future<ListAdsResp> listAds({String cursor = '', int pageSize = 20}) async {
    cursors.add(cursor);
    if (pages.isEmpty) throw Exception('offline');
    return pages.removeAt(0);
  }
}
