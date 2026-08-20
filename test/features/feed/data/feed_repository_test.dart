import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/v2_api_client.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parses nested recommend posts and keeps snapshot metadata', () async {
    final client = _StubV2ApiClient([
      {
        'items': [
          {
            'postId': 7,
            'post': postJson(7),
            'score': 0.8,
            'reason': 'similar',
            'recallSource': 'itemcf',
            'modelVersion': 'rank-v1',
            'experimentId': 'exp-a',
            'position': 1,
          },
        ],
        'nextCursor': 'opaque-next',
        'hasMore': true,
        'requestId': 'request-server',
      },
    ]);
    final repository = FeedRepository(
      client: client,
      identityStore: identityStore(),
    );

    final result = await repository.fetchPage(
      kind: FeedKind.recommend,
      pageSize: 20,
    );

    expect(client.calls.single.path, '/api/v2/feed/recommend');
    expect(client.calls.single.query['anonymousId'], 'anonymous-1');
    expect(client.calls.single.query['sessionId'], 'session-1');
    expect(client.calls.single.query['requestId'], 'request-1');
    expect(result.requestId, 'request-server');
    expect(result.recommendCursor, 'opaque-next');
    expect(result.hasMore, isTrue);
    expect(result.items.single.post.title, 'Post 7');
    expect(result.items.single.context.position, 1);
    expect(result.items.single.context.recallSource, 'itemcf');
    expect(result.items.single.context.score, 0.8);
  });

  test(
    'reuses recommend request id and makes page positions monotonic',
    () async {
      final client = _StubV2ApiClient([
        {
          'items': [
            {
              ...postJson(8),
              'postId': 8,
              'position': 1,
              'recallSource': 'popular',
            },
          ],
          'nextCursor': '',
          'hasMore': false,
          'requestId': 'request-1',
        },
      ]);
      final repository = FeedRepository(
        client: client,
        identityStore: identityStore(),
      );

      final result = await repository.fetchPage(
        kind: FeedKind.recommend,
        pageSize: 20,
        requestId: 'request-1',
        recommendCursor: 'opaque / +',
        positionOffset: 20,
      );

      expect(client.calls.single.query['requestId'], 'request-1');
      expect(client.calls.single.query['cursor'], 'opaque / +');
      expect(result.items.single.context.position, 21);
    },
  );

  test('passes both follow cursor values and parses a flat post', () async {
    final client = _StubV2ApiClient([
      {
        'items': [
          {...postJson(9), 'postId': 9},
        ],
        'hasMore': true,
        'nextCursorCreatedAt': 100,
        'nextCursorPostId': 9,
      },
    ]);
    final repository = FeedRepository(
      client: client,
      identityStore: identityStore(),
    );

    final result = await repository.fetchPage(
      kind: FeedKind.follow,
      pageSize: 10,
      requestId: 'follow-request',
      followCursor: const FollowFeedCursor(createdAt: 200, postId: 10),
    );

    expect(client.calls.single.query['cursorCreatedAt'], 200);
    expect(client.calls.single.query['cursorPostId'], '10');
    expect(result.followCursor.createdAt, 100);
    expect(result.followCursor.postId, 9);
    expect(result.items.single.context.scene, 'follow');
    expect(result.items.single.context.recallSource, 'follow');
  });

  test(
    'rejects slim feed metadata instead of rendering an empty card',
    () async {
      final client = _StubV2ApiClient([
        {
          'items': [
            {'postId': 1, 'position': 1},
          ],
          'hasMore': false,
          'requestId': 'request-1',
        },
      ]);
      final repository = FeedRepository(
        client: client,
        identityStore: identityStore(),
      );

      await expectLater(
        repository.fetchPage(kind: FeedKind.recommend, pageSize: 20),
        throwsA(
          isA<ApiException>().having(
            (error) => error.message,
            'message',
            contains('complete post'),
          ),
        ),
      );
    },
  );

  test('keeps snowflake post ids that arrive as decimal strings', () async {
    const snowflake = '348206251022356480';
    final client = _StubV2ApiClient([
      {
        'items': [
          {
            ...postJson(7),
            'id': snowflake,
            'postId': snowflake,
            'title': '继续联调帖',
          },
        ],
        'hasMore': false,
        'requestId': 'request-1',
      },
    ]);
    final repository = FeedRepository(
      client: client,
      identityStore: identityStore(),
    );

    final result = await repository.fetchPage(
      kind: FeedKind.recommend,
      pageSize: 20,
    );

    expect(result.items.single.post.id, snowflake);
    expect(result.items.single.post.title, '继续联调帖');
  });
}

ClientIdentityStore identityStore() =>
    ClientIdentityStore(generateId: (prefix) => '$prefix-1');

Map<String, dynamic> postJson(int id) => {
  'id': id,
  'authorId': 2,
  'authorName': 'Author',
  'authorAvatar': '',
  'title': 'Post $id',
  'content': 'Content',
  'images': <String>[],
  'tags': <String>[],
  'viewCount': 10,
  'likeCount': 2,
  'isLiked': false,
  'commentCount': 1,
  'createdAt': 1700000000,
};

class _ApiCall {
  final String path;
  final Map<String, Object?> query;

  const _ApiCall(this.path, this.query);
}

class _StubV2ApiClient extends V2ApiClient {
  final List<Map<String, dynamic>> responses;
  final List<_ApiCall> calls = [];

  _StubV2ApiClient(this.responses);

  @override
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, Object?> query = const {},
  }) async {
    calls.add(_ApiCall(path, Map.of(query)));
    return responses.removeAt(0);
  }
}
