import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/data/sponsored_parser.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

Map<String, dynamic> slotJson({
  String slotId = 'slot-4',
  Object? afterPosition = 4,
  Map<String, dynamic> ad = const {},
}) => {
  'slotId': slotId,
  'afterPosition': afterPosition,
  'ad': {
    'adId': 7001,
    'revision': 2,
    'advertiserName': 'Acme',
    'title': 'Title',
    'body': 'Body',
    'cta': 'Go',
    'landingUrl': 'https://Shop.Example.com/a?b=1',
    'landingDomain': 'shop.example.com',
    'images': ['https://cdn.example.com/a.png', 'javascript:alert(1)', 7],
    'disclosure': 'sponsored',
    'why': {'market': 'US', 'scene': 'home', 'personalized': false},
    ...ad,
  },
};

FeedEntry entry(int id, int position, {String requestId = 'r1'}) => FeedEntry(
  post: PostItem.fromJson({
    'id': id,
    'authorId': 1,
    'authorName': 'a',
    'authorAvatar': '',
    'title': 't$id',
    'content': '',
    'images': <String>[],
    'tags': <String>[],
    'viewCount': 0,
    'likeCount': 0,
    'isLiked': false,
    'commentCount': 0,
    'createdAt': 0,
  }),
  context: FeedRecommendationContext(
    requestId: requestId,
    scene: 'home',
    position: position,
    recallSource: 'popular',
    modelVersion: '',
    experimentId: '',
  ),
);

SponsoredSlot slot(String id, int after, {String requestId = 'r1'}) =>
    parseSponsoredSlots(
      [slotJson(slotId: id, afterPosition: after)],
      requestId: requestId,
      scene: 'home',
    ).slots.single;

void main() {
  group('parseSponsoredSlots', () {
    test('parses a valid slot with tracking context and safe images', () {
      final result = parseSponsoredSlots(
        [slotJson()],
        requestId: 'r1',
        scene: 'home',
      );

      expect(result.dropped, 0);
      final parsed = result.slots.single;
      expect(parsed.key, 'ad-r1-4-slot-4');
      expect(parsed.context.position, 4);
      expect(parsed.context.requestId, 'r1');
      expect(parsed.ad.landingDomain, 'shop.example.com');
      expect(parsed.ad.images, ['https://cdn.example.com/a.png']);
      expect(parsed.ad.why.market, 'US');
      expect(parsed.ad.why.personalized, isFalse);
    });

    test('drops each malformed slot independently and counts it', () {
      final result = parseSponsoredSlots(
        [
          slotJson(slotId: 'ok'),
          slotJson(slotId: 'no-disclosure', ad: {'disclosure': ''}),
          slotJson(
            slotId: 'http',
            ad: {'landingUrl': 'http://shop.example.com'},
          ),
          slotJson(slotId: 'mismatch', ad: {'landingDomain': 'evil.example'}),
          slotJson(
            slotId: 'userinfo',
            ad: {
              'landingUrl': 'https://user@shop.example.com/',
              'landingDomain': 'shop.example.com',
            },
          ),
          slotJson(slotId: 'no-title', ad: {'title': ' '}),
          slotJson(slotId: 'no-id', ad: {'adId': 0}),
          slotJson(slotId: 'zero', afterPosition: 0),
          slotJson(slotId: 'string-pos', afterPosition: '4'),
          slotJson(slotId: ''),
          slotJson(slotId: 'ok'),
          'not a map',
        ],
        requestId: 'r1',
        scene: 'home',
      );

      expect(result.slots.map((slot) => slot.slotId), ['ok']);
      expect(result.dropped, 11);
    });

    test('absent sponsored is empty, a non-list counts as one drop', () {
      expect(
        parseSponsoredSlots(null, requestId: 'r', scene: 'home').dropped,
        0,
      );
      final invalid = parseSponsoredSlots('x', requestId: 'r', scene: 'home');
      expect(invalid.slots, isEmpty);
      expect(invalid.dropped, 1);
    });
  });

  group('mergeFeedRows', () {
    test('places ads after the anchored natural entry only', () {
      final rows = mergeFeedRows(
        [entry(1, 1), entry(2, 2), entry(3, 3)],
        [slot('a', 2), slot('missing', 9), slot('other', 1, requestId: 'r2')],
      );

      expect(rows.map(_describe), ['p1', 'p2', 'ad:a', 'p3']);
    });

    test('keeps natural order when there are no slots', () {
      final rows = mergeFeedRows([entry(1, 1), entry(2, 2)], const []);
      expect(rows.map(_describe), ['p1', 'p2']);
    });
  });
}

String _describe(FeedRow row) => switch (row) {
  FeedPostRow(:final entry) => 'p${entry.post.id}',
  FeedAdRow(:final slot) => 'ad:${slot.slotId}',
};
