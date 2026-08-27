import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;

void main() {
  setUp(mock_router.resetMockState);

  Map<String, dynamic> bodyOf(mock_router.MockRouterResponse response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  Map<String, String> bearer([int userId = 1]) => {
    'Authorization': 'Bearer ${mock_router.mockAccessTokenForUser(userId)}',
  };

  test('health and ready match the Gateway payload shape', () {
    final health = mock_router.dispatchResponse('GET', '/api/v1/health', '');
    expect(health.statusCode, 200);
    expect(bodyOf(health)['status'], 'ok');
    expect(bodyOf(health).containsKey('data'), isFalse);

    final ready = mock_router.dispatchResponse(
      'GET',
      '/api/v1/health/ready',
      '',
    );
    expect(ready.statusCode, 200);
    expect(bodyOf(ready)['status'], 'ready');
    expect(bodyOf(ready)['dependencies'], isA<Map>());
  });

  test('optional auth routes advertise x-auth-state', () {
    final anonymous = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts?page=1&pageSize=20',
      '',
    );
    expect(anonymous.statusCode, 200);
    expect(anonymous.headers['x-auth-state'], 'anonymous');
    expect(bodyOf(anonymous)['list'], isA<List>());

    final authenticated = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts',
      '',
      headers: bearer(),
    );
    expect(authenticated.headers['x-auth-state'], 'authenticated');

    final invalid = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts',
      '',
      headers: const {'Authorization': 'Token nope'},
    );
    expect(invalid.statusCode, 200);
    expect(invalid.headers['x-auth-state'], 'invalid');

    final expired = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts',
      '',
      headers: {
        'Authorization': 'Bearer ${mock_router.mockExpiredTokenForUser(1)}',
      },
    );
    expect(expired.statusCode, 200);
    expect(expired.headers['x-auth-state'], 'expired');

    // 楼中楼回复列表同为 OptionalAuth：匿名可读，带鉴权态标记
    final replies = mock_router.dispatchResponse(
      'GET',
      '/api/v1/comments/1/replies?page=1&pageSize=20',
      '',
    );
    expect(replies.statusCode, 200);
    expect(replies.headers['x-auth-state'], 'anonymous');
    expect(bodyOf(replies)['list'], isA<List>());
    expect(bodyOf(replies), containsPair('total', isA<num>()));
  });

  test(
    'comment list embeds reply preview and replies endpoint paginates asc',
    () {
      final list = bodyOf(
        mock_router.dispatchResponse(
          'GET',
          '/api/v1/comments/1?page=1&pageSize=50',
          '',
        ),
      );
      final threads = (list['list'] as List).cast<Map<String, dynamic>>();
      final threadWithReplies = threads.firstWhere(
        (c) => (c['replyCount'] as num).toInt() > 0,
      );
      expect(threadWithReplies['replies'], isA<List>());
      final preview = (threadWithReplies['replies'] as List).length;
      expect(preview, lessThanOrEqualTo(3));

      final replies = bodyOf(
        mock_router.dispatchResponse(
          'GET',
          '/api/v1/comments/${threadWithReplies['id']}/replies?page=1&pageSize=20',
          '',
        ),
      );
      expect(
        (replies['total'] as num).toInt(),
        threadWithReplies['replyCount'],
      );
      final rows = (replies['list'] as List).cast<Map<String, dynamic>>();
      for (final row in rows) {
        expect((row['parentId'] as num).toInt(), threadWithReplies['id']);
        expect((row['replies'] as List).isEmpty, isTrue);
      }
      final created = rows.map((r) => r['createdAt'] as num).toList();
      expect(created, equals([...created]..sort()));

      // 回复楼中楼不存在：父评论必须是顶级评论
      if (rows.isNotEmpty) {
        final nested = mock_router.dispatchResponse(
          'GET',
          '/api/v1/comments/${rows.first['id']}/replies?page=1&pageSize=20',
          '',
        );
        expect(nested.statusCode, 404);
      }
    },
  );

  test('jwt-required routes return 401 login required without Bearer', () {
    const protected = [
      ['POST', '/api/v1/comment', '{"postId":1,"content":"hi"}'],
      ['POST', '/api/v1/like', '{"targetId":1,"targetType":1}'],
      ['POST', '/api/v2/post', '{"title":"t","content":"c","status":1}'],
      ['GET', '/api/v2/me/personalization', ''],
      ['GET', '/api/v2/feed/follow?pageSize=20', ''],
      ['GET', '/api/v2/assistant/memory', ''],
      ['GET', '/api/v2/assistant/watch', ''],
      ['GET', '/api/v2/assistant/watch/hits', ''],
      [
        'POST',
        '/api/v2/assistant/recommend/feedback',
        '{"postId":1,"reason":"dislike"}',
      ],
    ];
    for (final entry in protected) {
      final response = mock_router.dispatchResponse(
        entry[0],
        entry[1],
        entry[2],
      );
      expect(response.statusCode, 401, reason: entry[1]);
      expect(bodyOf(response)['code'], 1006, reason: entry[1]);
      expect(bodyOf(response)['message'], '请先登录');
    }
  });

  test('unknown routes and bad path ids use Gateway error codes', () {
    final missing = mock_router.dispatchResponse('GET', '/api/v1/nope', '');
    expect(missing.statusCode, 404);
    expect(bodyOf(missing)['code'], 4);

    final badUser = mock_router.dispatchResponse(
      'GET',
      '/api/v1/user/not-a-number',
      '',
    );
    expect(badUser.statusCode, 400);
    expect(bodyOf(badUser)['code'], 2);

    // 游标契约：page 参数已移除，坏游标（非法 base64/JSON）报参数错误。
    final badPage = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts?cursor=%%%not-base64%%%',
      '',
    );
    expect(badPage.statusCode, 400);
    expect(bodyOf(badPage)['code'], 2);
  });

  test('private favorites and register uniqueness match business codes', () {
    final private = mock_router.dispatchResponse(
      'GET',
      '/api/v1/users/3/favorites?page=1&pageSize=20',
      '',
    );
    expect(private.statusCode, 403);
    expect(bodyOf(private)['code'], 3007);

    final created = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/register',
      jsonEncode({'username': 'newuser', 'password': 'Strong123'}),
    );
    expect(created.statusCode, 200);
    expect(bodyOf(created)['userId'], greaterThan(0));

    final duplicate = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/register',
      jsonEncode({'username': 'newuser', 'password': 'Strong123'}),
    );
    expect(duplicate.statusCode, 409);
    expect(bodyOf(duplicate)['code'], 1002);
  });

  test(
    'personalization and media image require jwt and return typed payloads',
    () {
      final headers = bearer();
      final pref = mock_router.dispatchResponse(
        'GET',
        '/api/v2/me/personalization',
        '',
        headers: headers,
      );
      expect(pref.statusCode, 200);
      expect(bodyOf(pref)['enabled'], isTrue);

      expect(
        mock_router
            .dispatchResponse(
              'PUT',
              '/api/v2/me/personalization',
              jsonEncode({'enabled': false}),
              headers: headers,
            )
            .statusCode,
        200,
      );
      expect(
        bodyOf(
          mock_router.dispatchResponse(
            'GET',
            '/api/v2/me/personalization',
            '',
            headers: headers,
          ),
        )['enabled'],
        isFalse,
      );

      final notMultipart = mock_router.dispatchResponse(
        'POST',
        '/api/v1/media/image',
        'not-multipart',
        headers: headers,
      );
      expect(notMultipart.statusCode, 400);

      final uploaded = mock_router.dispatchResponse(
        'POST',
        '/api/v1/media/image',
        '<multipart-1-files>',
        headers: headers,
      );
      expect(uploaded.statusCode, 200);
      expect(
        bodyOf(uploaded).keys,
        containsAll(['mediaId', 'url', 'thumbnailUrl']),
      );
    },
  );

  test('assistant memory watch and feedback return typed payloads', () {
    final headers = bearer();
    final memory = bodyOf(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/assistant/memory',
        '',
        headers: headers,
      ),
    );
    expect(memory['items'], isA<List>());
    expect((memory['items'] as List), isNotEmpty);
    expect(
      (memory['items'] as List).every(
        (item) => (item as Map)['layer'] != 'episodic',
      ),
      isTrue,
    );

    final watches = bodyOf(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/assistant/watch',
        '',
        headers: headers,
      ),
    );
    expect(watches['tasks'], isA<List>());

    final created = bodyOf(
      mock_router.dispatchResponse(
        'POST',
        '/api/v2/assistant/watch',
        jsonEncode({
          'conditionType': 'tag_new_post',
          'targetType': 'tag',
          'targetText': '美食',
        }),
        headers: headers,
      ),
    );
    expect((created['task'] as Map)['id'], greaterThan(0));
    expect((created['task'] as Map)['conditionType'], 'tag_new_post');

    final unknown = mock_router.dispatchResponse(
      'POST',
      '/api/v2/assistant/watch',
      jsonEncode({
        'conditionType': 'discussion_spike',
        'targetType': 'post',
        'targetId': 1,
      }),
      headers: headers,
    );
    expect(unknown.statusCode, 400);

    final hits = bodyOf(
      mock_router.dispatchResponse(
        'GET',
        '/api/v2/assistant/watch/hits',
        '',
        headers: headers,
      ),
    );
    expect(hits['hits'], isA<List>());
    final hitId = ((hits['hits'] as List).first as Map)['id'];

    expect(
      mock_router
          .dispatchResponse(
            'POST',
            '/api/v2/assistant/watch/hits/read',
            jsonEncode({
              'hitIds': [hitId],
            }),
            headers: headers,
          )
          .statusCode,
      200,
    );

    final feedback = mock_router.dispatchResponse(
      'POST',
      '/api/v2/assistant/recommend/feedback',
      jsonEncode({'postId': 1, 'reason': 'dislike'}),
      headers: headers,
    );
    expect(feedback.statusCode, 200);
  });
}
