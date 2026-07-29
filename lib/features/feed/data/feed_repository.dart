import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/v2_api_client.dart';
import '../../../sdk/data/gateway.dart';
import 'feed_models.dart';

abstract interface class FeedPageRepository {
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  });
}

class FeedRepository implements FeedPageRepository {
  final V2ApiClient _client;
  final ClientIdentityStore _identityStore;

  const FeedRepository({
    V2ApiClient client = const V2ApiClient(),
    required ClientIdentityStore identityStore,
  }) : _client = client,
       _identityStore = identityStore;

  @override
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  }) async {
    if (pageSize <= 0 || pageSize > 100) {
      throw const ApiException('Feed pageSize must be between 1 and 100');
    }

    final snapshotRequestId = requestId.isEmpty
        ? await _identityStore.createRequestId()
        : requestId;
    return switch (kind) {
      FeedKind.recommend => _fetchRecommend(
        pageSize: pageSize,
        requestId: snapshotRequestId,
        cursor: recommendCursor,
        positionOffset: positionOffset,
      ),
      FeedKind.follow => _fetchFollow(
        pageSize: pageSize,
        requestId: snapshotRequestId,
        cursor: followCursor,
        positionOffset: positionOffset,
      ),
    };
  }

  Future<FeedPageResult> _fetchRecommend({
    required int pageSize,
    required String requestId,
    required String cursor,
    required int positionOffset,
  }) async {
    final identity = await _identityStore.loadOrCreate();
    final response = await _client.get(
      '/api/v2/feed/recommend',
      query: {
        'anonymousId': identity.anonymousId,
        'sessionId': identity.sessionId,
        'scene': 'home',
        'requestId': requestId,
        'cursor': cursor,
        'pageSize': pageSize,
      },
    );
    final responseRequestId = _string(response['requestId']);
    final effectiveRequestId = responseRequestId.isEmpty
        ? requestId
        : responseRequestId;
    final items = _parseItems(
      response['items'],
      requestId: effectiveRequestId,
      scene: 'home',
      positionOffset: positionOffset,
      recommendation: true,
    );
    return FeedPageResult(
      items: items,
      hasMore: response['hasMore'] == true,
      requestId: effectiveRequestId,
      recommendCursor: _string(response['nextCursor']),
    );
  }

  Future<FeedPageResult> _fetchFollow({
    required int pageSize,
    required String requestId,
    required FollowFeedCursor cursor,
    required int positionOffset,
  }) async {
    final response = await _client.get(
      '/api/v2/feed/follow',
      query: {
        if (cursor.createdAt > 0) 'cursorCreatedAt': cursor.createdAt,
        if (cursor.postId > 0) 'cursorPostId': cursor.postId,
        'pageSize': pageSize,
      },
    );
    final items = _parseItems(
      response['items'],
      requestId: requestId,
      scene: 'follow',
      positionOffset: positionOffset,
      recommendation: false,
    );
    return FeedPageResult(
      items: items,
      hasMore: response['hasMore'] == true,
      requestId: requestId,
      followCursor: FollowFeedCursor(
        createdAt: _integer(response['nextCursorCreatedAt']),
        postId: _integer(response['nextCursorPostId']),
      ),
    );
  }

  List<FeedEntry> _parseItems(
    Object? rawItems, {
    required String requestId,
    required String scene,
    required int positionOffset,
    required bool recommendation,
  }) {
    if (rawItems is! List) {
      throw const ApiException('Feed response is missing items');
    }

    return rawItems.indexed.map((indexed) {
      final (index, raw) = indexed;
      if (raw is! Map) {
        throw const ApiException('Feed response contains an invalid item');
      }
      final item = Map<String, dynamic>.from(raw);
      final post = _parsePost(item);
      final fallbackPosition = positionOffset + index + 1;
      final serverPosition = _integer(item['position']);
      final position = serverPosition > positionOffset
          ? serverPosition
          : fallbackPosition;
      return FeedEntry(
        post: post,
        context: FeedRecommendationContext(
          requestId: requestId,
          scene: scene,
          position: position,
          score: recommendation ? _decimal(item['score']) : 0,
          reason: recommendation ? _string(item['reason']) : '',
          recallSource: recommendation
              ? _string(item['recallSource'])
              : 'follow',
          modelVersion: recommendation ? _string(item['modelVersion']) : '',
          experimentId: recommendation ? _string(item['experimentId']) : '',
        ),
      );
    }).toList();
  }

  PostItem _parsePost(Map<String, dynamic> item) {
    final nested = item['post'];
    final post = nested is Map
        ? Map<String, dynamic>.from(nested)
        : Map<String, dynamic>.from(item);
    post.putIfAbsent('id', () => item['postId']);

    const requiredKeys = {
      'id',
      'authorId',
      'authorName',
      'authorAvatar',
      'title',
      'content',
      'images',
      'tags',
      'viewCount',
      'likeCount',
      'isLiked',
      'commentCount',
      'createdAt',
    };
    if (_integer(post['id']) <= 0 || !requiredKeys.every(post.containsKey)) {
      throw const ApiException(
        'Feed item is missing the complete post payload',
      );
    }
    try {
      return PostItem.fromJson(post);
    } catch (_) {
      throw const ApiException('Feed item contains an invalid post payload');
    }
  }

  static String _string(Object? value) => value?.toString() ?? '';

  static int _integer(Object? value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _decimal(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
