import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;

void main() {
  const jsonHeaders = {'content-type': 'application/json'};
  const feedItemFields = [
    'postId',
    'authorId',
    'authorName',
    'authorAvatar',
    'createdAt',
    'feedType',
    'title',
    'content',
    'images',
    'tags',
    'viewCount',
    'likeCount',
    'commentCount',
    'favoriteCount',
    'isLiked',
  ];

  setUp(mock_router.resetMockState);

  Map<String, dynamic> decodeBody(mock_router.MockRouterResponse response) {
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, String> authHeaders([int userId = 1]) => {
    'Authorization': 'Bearer ${mock_router.mockAccessTokenForUser(userId)}',
  };

  test('recommend feed is a flat Gateway item with opaque cursor pagination', () {
    final first = mock_router.dispatchResponse(
      'GET',
      '/api/v2/feed/recommend?anonymousId=device-1&requestId=request-1&pageSize=2',
      '',
    );
    final firstBody = decodeBody(first);
    final firstItems = firstBody['items'] as List<dynamic>;

    expect(first.statusCode, 200);
    expect(first.headers['x-auth-state'], 'anonymous');
    expect(firstBody['requestId'], 'request-1');
    expect(firstBody['hasMore'], isTrue);
    expect(firstBody['nextCursor'], isNotEmpty);
    expect(firstItems, hasLength(2));

    final firstItem = firstItems.first as Map<String, dynamic>;
    expect(firstItem.keys, containsAll(feedItemFields));
    expect(firstItem.containsKey('post'), isFalse);
    expect(
      firstItem.keys,
      containsAll([
        'score',
        'reason',
        'recallSource',
        'modelVersion',
        'experimentId',
        'position',
      ]),
    );
    expect(firstItem['position'], 1);

    final cursor = firstBody['nextCursor'] as String;
    final secondPath = Uri(
      path: '/api/v2/feed/recommend',
      queryParameters: {
        'anonymousId': 'device-1',
        'requestId': 'request-1',
        'pageSize': '2',
        'cursor': cursor,
      },
    ).toString();
    final second = decodeBody(
      mock_router.dispatchResponse('GET', secondPath, ''),
    );
    final secondItems = second['items'] as List<dynamic>;

    expect((secondItems.first as Map<String, dynamic>)['position'], 3);
    expect(
      (secondItems.first as Map<String, dynamic>)['postId'],
      isNot(firstItem['postId']),
    );
  });

  test('recommend accepts Bearer identity without anonymous id', () {
    final response = mock_router.dispatchResponse(
      'GET',
      '/api/v2/feed/recommend?requestId=request-auth&pageSize=1',
      '',
      headers: authHeaders(),
    );

    expect(response.statusCode, 200);
    expect(response.headers['x-auth-state'], 'authenticated');
    expect(decodeBody(response)['requestId'], 'request-auth');
  });

  test('follow feed requires Bearer and only returns followed authors', () {
    final unauthorized = mock_router.dispatchResponse(
      'GET',
      '/api/v2/feed/follow?pageSize=2',
      '',
    );
    expect(unauthorized.statusCode, 401);
    expect(decodeBody(unauthorized)['code'], 1006);

    final headers = authHeaders();
    final first = mock_router.dispatchResponse(
      'GET',
      '/api/v2/feed/follow?pageSize=2',
      '',
      headers: headers,
    );
    final firstBody = decodeBody(first);
    final firstItems = firstBody['items'] as List<dynamic>;
    expect(first.statusCode, 200);
    expect(firstItems, hasLength(2));
    expect(firstBody['hasMore'], isTrue);
    expect(
      (firstItems.first as Map<String, dynamic>).keys,
      containsAll(feedItemFields),
    );
    expect(
      firstItems.map((item) => (item as Map<String, dynamic>)['authorId']),
      everyElement(isNot(1)),
    );

    final secondPath = Uri(
      path: '/api/v2/feed/follow',
      queryParameters: {
        'pageSize': '2',
        'cursorCreatedAt': '${firstBody['nextCursorCreatedAt']}',
        'cursorPostId': '${firstBody['nextCursorPostId']}',
      },
    ).toString();
    final secondBody = decodeBody(
      mock_router.dispatchResponse('GET', secondPath, '', headers: headers),
    );
    final secondItems = secondBody['items'] as List<dynamic>;
    final firstIds = firstItems
        .map((item) => (item as Map<String, dynamic>)['postId'])
        .toSet();

    expect(secondItems, hasLength(2));
    expect(
      secondItems.map((item) => (item as Map<String, dynamic>)['postId']),
      everyElement(isNot(isIn(firstIds))),
    );
  });

  test('behavior endpoint returns 202 with per-event accept or reject', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final response = mock_router.dispatchResponse(
      'POST',
      '/api/v2/behavior/events',
      jsonEncode({
        'anonymousId': 'device-1',
        'sessionId': 'session-1',
        'events': [
          {
            'clientEventId': 'event-1',
            'occurredAt': now,
            'action': 'exposure',
            'targetId': 1,
            'targetType': 'post',
            'scene': 'home',
            'requestId': 'request-1',
            'position': 1,
          },
          {
            'clientEventId': 'event-2',
            'occurredAt': now,
            'action': 'click',
            'targetId': 1,
            'targetType': 'post',
          },
          {
            'clientEventId': 'event-like',
            'occurredAt': now,
            'action': 'like',
            'targetId': 1,
            'targetType': 'post',
          },
        ],
      }),
      headers: jsonHeaders,
    );
    final body = decodeBody(response);
    final results = body['results'] as List<dynamic>;

    expect(response.statusCode, 202);
    expect(response.headers['x-auth-state'], 'anonymous');
    expect(body['acceptedCount'], 2);
    expect(body['rejectedCount'], 1);
    expect(results, hasLength(3));
    expect((results[2] as Map<String, dynamic>)['accepted'], isFalse);
    expect(
      (results[2] as Map<String, dynamic>)['reason'],
      contains('not allowed from clients'),
    );
  });

  test('search endpoints return post, user, and tag result contracts', () {
    final all = mock_router.dispatchResponse(
      'GET',
      '/api/v2/search?keyword=%E7%A7%91%E6%8A%80&page=1&pageSize=20',
      '',
    );
    final allBody = decodeBody(all);
    expect(all.statusCode, 200);
    expect(allBody['posts'], isNotEmpty);
    expect(allBody['users'], isNotEmpty);
    expect(allBody['tags'], isNotEmpty);
    expect(allBody['degraded'], isFalse);

    final empty = mock_router.dispatchResponse(
      'GET',
      '/api/v2/search?keyword=&page=1&pageSize=20',
      '',
    );
    expect(empty.statusCode, 400);
    expect(decodeBody(empty)['code'], 5001);

    final users = decodeBody(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/search/users?keyword=tech&page=1&pageSize=20',
        '',
      ),
    );
    expect(users['total'], 1);
    expect((users['users'] as List<dynamic>).single, containsPair('id', 3));

    final tags = decodeBody(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/search/tags?keyword=%E6%89%8B%E6%9C%BA&limit=20',
        '',
      ),
    );
    expect((tags['tags'] as List<dynamic>).single, containsPair('name', '手机'));
  });

  test('message mock supports auth, read state, and idempotent sending', () {
    final unauthorized = mock_router.dispatchResponse(
      'GET',
      '/api/v2/messages/conversations?page=1&pageSize=20',
      '',
    );
    expect(unauthorized.statusCode, 401);

    final headers = authHeaders();
    final listResponse = mock_router.dispatchResponse(
      'GET',
      '/api/v2/messages/conversations?page=1&pageSize=20',
      '',
      headers: headers,
    );
    final list = decodeBody(listResponse);
    expect(listResponse.statusCode, 200);
    expect(list['total'], 2);
    expect(list['conversations'], hasLength(2));

    final detail = decodeBody(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/messages/conversations/11?pageSize=20',
        '',
        headers: headers,
      ),
    );
    expect(detail['messages'], hasLength(2));

    final command = jsonEncode({
      'receiverId': 2,
      'content': '收到，周末见',
      'msgType': 1,
      'idempotencyKey': 'mock-message-idempotency-test',
    });
    final firstSend = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/messages',
        command,
        headers: headers,
      ),
    );
    final replay = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/messages',
        command,
        headers: headers,
      ),
    );
    expect(firstSend['messageId'], greaterThan(0));
    expect(replay['messageId'], firstSend['messageId']);

    final unreadBefore = decodeBody(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/messages/unread',
        '',
        headers: headers,
      ),
    );
    expect(unreadBefore['messageUnread'], 2);
    expect(
      mock_router
          .dispatchResponse(
            'POST',
            '/api/v2/messages/conversations/11/read',
            '{}',
            headers: headers,
          )
          .statusCode,
      200,
    );
    final unreadAfter = decodeBody(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/messages/unread',
        '',
        headers: headers,
      ),
    );
    expect(unreadAfter['messageUnread'], 0);
  });

  test('assistant mock posts a message then emits source_card SSE', () {
    final posted = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/assistant/messages',
        jsonEncode({
          'message': '推荐一篇探店帖子',
          'requestId': 'assistant-mock-test',
        }),
        headers: {...authHeaders(), 'content-type': 'application/json'},
      ),
    );
    expect(posted['disposition'], 'started');
    expect(posted['runId'], greaterThan(0));

    final response = mock_router.dispatchResponse(
      'GET',
      '/api/v2/assistant/runs/${posted['runId']}/events',
      '',
      headers: authHeaders(),
    );

    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/event-stream');
    expect(response.body, contains('"type":"token"'));
    expect(response.body, contains('"type":"source_card"'));
    expect(response.body, contains('"type":"done"'));
    expect(response.body, contains('"kind":"post"'));
    expect(response.body, isNot(contains('"type":"source"')));
    expect(response.body, isNot(contains('"type":"card"')));
  });

  test('assistant run events reconnect from Last-Event-ID', () {
    final posted = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/assistant/messages',
        jsonEncode({'message': 'hello', 'requestId': 'reconnect'}),
        headers: {...authHeaders(), 'content-type': 'application/json'},
      ),
    );
    final response = mock_router.dispatchResponse(
      'GET',
      '/api/v2/assistant/runs/${posted['runId']}/events?afterSeq=1',
      '',
      headers: {...authHeaders(), 'Last-Event-ID': '1'},
    );
    expect(response.body, isNot(contains('"seq":1')));
    expect(response.body, contains('"type":"token"'));
  });

  test('v2 post writes require revision and stay idempotent', () {
    final headers = authHeaders();
    final created = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/post',
        jsonEncode({
          'title': '新帖标题',
          'content': '新帖正文',
          'status': 1,
          'idempotencyKey': 'post-key-1',
        }),
        headers: headers,
      ),
    );
    expect(created['postId'], greaterThan(0));
    expect(created['revision'], 1);

    final replay = decodeBody(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/post',
        jsonEncode({
          'title': '新帖标题',
          'content': '新帖正文',
          'status': 1,
          'idempotencyKey': 'post-key-1',
        }),
        headers: headers,
      ),
    );
    expect(replay['postId'], created['postId']);

    final missingRevision = mock_router.dispatchResponse(
      'PUT',
      '/api/v2/post/${created['postId']}',
      jsonEncode({'title': '改标题'}),
      headers: headers,
    );
    expect(missingRevision.statusCode, 400);
    expect(decodeBody(missingRevision)['code'], 2);

    final conflict = mock_router.dispatchResponse(
      'PUT',
      '/api/v2/post/${created['postId']}',
      jsonEncode({'title': '改标题', 'content': '新帖正文', 'expectedRevision': 99}),
      headers: headers,
    );
    expect(conflict.statusCode, 409);
    expect(decodeBody(conflict)['code'], 2007);
  });

  test(
    'MockHttpClient forwards headers and preserves response metadata',
    () async {
      final client = MockHttpClient();
      addTearDown(client.close);
      final token = mock_router.mockAccessTokenForUser(1);

      final follow = await client.get(
        Uri.parse('http://mock/api/v2/feed/follow?pageSize=1'),
        headers: {'Authorization': 'Bearer $token'},
      );
      expect(follow.statusCode, 200);

      final now = DateTime.now().millisecondsSinceEpoch;
      final behavior = await client.post(
        Uri.parse('http://mock/api/v2/behavior/events'),
        headers: jsonHeaders,
        body: jsonEncode({
          'anonymousId': 'device-1',
          'events': [
            {
              'clientEventId': 'event-http',
              'occurredAt': now,
              'action': 'click',
              'targetId': 1,
              'targetType': 'post',
            },
          ],
        }),
      );
      expect(behavior.statusCode, 202);
      expect(behavior.headers['content-type'], contains('application/json'));
    },
  );
}
