import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/review/data/review_snapshot.dart';

void main() {
  test('parses the frozen canonical snapshot', () {
    final snapshot = ReviewSnapshotView.parse('''
{"bizType":"ad_creative","snapshot":{
  "texts":{"cta":"Go","title":"T","advertiser":"Acme","extra":"x","body":"B"},
  "landingUrl":"https://shop.example.com/p?q=1",
  "media":[{"mediaId":12345678901234567,"sha256":"ab"},{"mediaId":0}],
  "market":"US","language":"en","industry":"GENERAL","submitterId":7,
  "qualifications":[{"market":"DE","industry":"FINANCIAL","documentMediaId":9,"validUntilMs":1900000000000}]
}}''');

    expect(snapshot.valid, isTrue);
    expect(snapshot.orderedTexts.map((e) => e.key), [
      'advertiser',
      'title',
      'body',
      'cta',
      'extra',
    ]);
    expect(snapshot.landingHost, 'shop.example.com');
    expect(snapshot.media.single.mediaId.toString(), '12345678901234567');
    expect(snapshot.qualifications.single.industry, 'FINANCIAL');
    expect(snapshot.qualifications.single.validUntilMs, 1900000000000);
  });

  test('accepts a flat snapshot and rejects garbage without throwing', () {
    expect(ReviewSnapshotView.parse('{"texts":{"name":"A"}}').texts, {
      'name': 'A',
    });
    expect(ReviewSnapshotView.parse('not json').valid, isFalse);
    expect(ReviewSnapshotView.parse('[1]').valid, isFalse);
  });

  test('stage output rows expand JSON objects and keep raw text', () {
    expect(reviewStageOutputRows('{"scores":{"A":0.5},"hits":[]}'), [
      isA<MapEntry<String, String>>()
          .having((e) => e.key, 'key', 'scores')
          .having((e) => e.value, 'value', '{"A":0.5}'),
      isA<MapEntry<String, String>>().having((e) => e.value, 'value', '[]'),
    ]);
    expect(reviewStageOutputRows('oops').single.value, 'oops');
    expect(reviewStageOutputRows(''), isEmpty);
    expect(isPlaceholderComponent('stub-v0'), isTrue);
    expect(isPlaceholderComponent('rules-v1'), isFalse);
  });
}
