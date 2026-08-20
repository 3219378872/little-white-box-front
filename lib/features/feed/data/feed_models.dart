import '../../../sdk/data/gateway.dart';

enum FeedKind { recommend, follow }

class FeedRecommendationContext {
  final String requestId;
  final String scene;
  final int position;
  final double score;
  final String reason;
  final String recallSource;
  final String modelVersion;
  final String experimentId;

  const FeedRecommendationContext({
    required this.requestId,
    required this.scene,
    required this.position,
    this.score = 0,
    this.reason = '',
    required this.recallSource,
    required this.modelVersion,
    required this.experimentId,
  });
}

class FeedEntry {
  final PostItem post;
  final FeedRecommendationContext context;

  const FeedEntry({required this.post, required this.context});
}

class FollowFeedCursor {
  final int createdAt;
  final Object postId;

  const FollowFeedCursor({this.createdAt = 0, this.postId = 0});
}

class FeedPageResult {
  final List<FeedEntry> items;
  final bool hasMore;
  final String requestId;
  final String recommendCursor;
  final FollowFeedCursor followCursor;

  const FeedPageResult({
    required this.items,
    required this.hasMore,
    required this.requestId,
    this.recommendCursor = '',
    this.followCursor = const FollowFeedCursor(),
  });
}
