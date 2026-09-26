import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/feed/application/trending_tags.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

void main() {
  test('ranks by post count, then first appearance, deduping per post', () {
    final ranked = rankTrendingTags([
      _entry(1, ['go', 'go', ' ']),
      _entry(2, ['flutter', 'go']),
      _entry(3, ['rust', 'flutter']),
      _entry(4, ['rust']),
    ]);

    expect(ranked.map((tag) => tag.name), ['go', 'flutter', 'rust']);
    expect(ranked.map((tag) => tag.postCount), [2, 2, 2]);
  });

  test('respects the limit and returns nothing for an empty feed', () {
    expect(rankTrendingTags(const []), isEmpty);
    final ranked = rankTrendingTags([
      _entry(1, ['a', 'b', 'c']),
    ], limit: 2);
    expect(ranked.map((tag) => tag.name), ['a', 'b']);
  });
}

FeedEntry _entry(int id, List<String> tags) => FeedEntry(
  post: PostItem(
    id: id,
    authorId: 1,
    authorName: 'Author',
    authorAvatar: '',
    title: 'Post $id',
    content: '',
    images: const [],
    mediaIds: const [],
    tags: tags,
    status: 1,
    viewCount: 0,
    likeCount: 0,
    isLiked: false,
    isFavorited: false,
    favoriteCount: 0,
    commentCount: 0,
    revision: 1,
    createdAt: 1700000000,
  ),
  context: FeedRecommendationContext(
    requestId: 'request',
    scene: 'home',
    position: id,
    recallSource: 'popular',
    modelVersion: 'rule-v1',
    experimentId: '',
  ),
);
