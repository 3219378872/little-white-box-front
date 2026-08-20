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

    final ready = mock_router.dispatchResponse('GET', '/api/v1/health/ready', '');
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
  });

  test('jwt-required routes return 401 login required without Bearer', () {
    const protected = [
      ['POST', '/api/v1/comment', '{"postId":1,"content":"hi"}'],
      ['POST', '/api/v1/like', '{"targetId":1,"targetType":1}'],
      ['POST', '/api/v2/post', '{"title":"t","content":"c","status":1}'],
      ['GET', '/api/v2/me/personalization', ''],
      ['GET', '/api/v2/feed/follow?pageSize=20', ''],
    ];
    for (final entry in protected) {
      final response = mock_router.dispatchResponse(entry[0], entry[1], entry[2]);
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

    final badPage = mock_router.dispatchResponse(
      'GET',
      '/api/v1/posts?page=not-a-number',
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

  test('personalization and media image require jwt and return typed payloads', () {
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
    expect(bodyOf(uploaded).keys, containsAll(['mediaId', 'url', 'thumbnailUrl']));
  });
}
