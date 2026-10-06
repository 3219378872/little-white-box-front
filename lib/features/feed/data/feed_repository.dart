import '../../../core/analytics/client_identity_store.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/v2_api_client.dart';
import '../../../sdk/data/gateway.dart';
import 'feed_models.dart';
import 'sponsored_parser.dart';

/// 信息流分页数据源接口，notifier 只依赖它，测试可替换。
abstract interface class FeedPageRepository {
  /// 读取一页信息流；[requestId] 为空表示开启新一轮快照，[positionOffset] 是已加载的自然条目数。
  Future<FeedPageResult> fetchPage({
    required FeedKind kind,
    required int pageSize,
    String requestId = '',
    String recommendCursor = '',
    FollowFeedCursor followCursor = const FollowFeedCursor(),
    int positionOffset = 0,
  });
}

/// 走 Gateway v2 信息流接口的实现：推荐 `/api/v2/feed/recommend`、关注 `/api/v2/feed/follow`。
///
/// 自然条目严格解析，任何缺字段都使整页失败；广告槽位逐个容错解析，见 `parseSponsoredSlots`。
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

    // 首屏生成新的请求 ID，续翻沿用调用方传入的同一个。
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

  // 推荐流：带匿名设备与会话标识，每页请求 1 个广告位。
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
        'adSlots': 1,
      },
    );
    final responseRequestId = _string(response['requestId']);
    // 服务端回传的请求 ID 优先，缺失时沿用本地生成的值。
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
    final sponsored = parseSponsoredSlots(
      response['sponsored'],
      requestId: effectiveRequestId,
      scene: 'home',
    );
    return FeedPageResult(
      items: items,
      hasMore: response['hasMore'] == true,
      requestId: effectiveRequestId,
      recommendCursor: _string(response['nextCursor']),
      sponsored: sponsored.slots,
      droppedSponsored: sponsored.dropped,
    );
  }

  // 关注流：按复合游标翻页，不含广告；条目的召回来源固定标为 follow。
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
        if (jsonInt64IsPositive(cursor.postId))
          'cursorPostId': jsonInt64Id(cursor.postId),
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
        postId: response['nextCursorPostId'] ?? 0,
      ),
    );
  }

  // 解析自然条目并补齐推荐上下文；非推荐流不带打分与实验字段。
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
      // 服务端位置大于已加载条目数才采用，否则按本地序号推算，避免与之前页面的位置冲突。
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

  // 兼容 `{post: {...}}` 嵌套与扁平两种条目结构；帖子字段必须完整，否则视为契约错误。
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
    if (!jsonInt64IsPositive(post['id']) ||
        !requiredKeys.every(post.containsKey)) {
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

  // 宽松读取工具：缺失或无法解析时分别回落为空串、0、0.0。
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
