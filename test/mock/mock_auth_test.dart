import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/auth/jwt_decoder.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;

void main() {
  setUp(mock_router.resetMockState);

  test('Mock login returns the seed user and a usable token', () {
    final response = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      jsonEncode({
        'username': 'xiaobaige',
        'password': mock_router.mockDevPassword,
        'loginType': 1,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    expect(response.statusCode, 200);
    expect(body['userId'], 1);
    expect(extractUserIdFromToken(body['token'] as String), 1);

    final alias = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      jsonEncode({
        'username': 'admin',
        'password': mock_router.mockDevPassword,
        'loginType': 1,
      }),
    );
    expect(alias.statusCode, 200);
    expect(jsonDecode(alias.body)['userId'], 1);
  });

  test('login rejects empty credentials and unknown users', () {
    final empty = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      '{}',
    );
    expect(empty.statusCode, 400);
    expect(jsonDecode(empty.body)['code'], 2);

    final missing = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      jsonEncode({
        'username': 'nobody',
        'password': 'whatever',
        'loginType': 1,
      }),
    );
    expect(missing.statusCode, 404);
    expect(jsonDecode(missing.body)['code'], 1001);

    final wrong = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      jsonEncode({
        'username': 'xiaobaige',
        'password': 'wrong-password',
        'loginType': 1,
      }),
    );
    expect(wrong.statusCode, 401);
    expect(jsonDecode(wrong.body)['code'], 1003);
  });

  test('登录与注册返回带有效期的双令牌', () {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final login = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/login',
      jsonEncode({
        'username': 'xiaobaige',
        'password': mock_router.mockDevPassword,
        'loginType': 1,
      }),
    );
    final loginBody = jsonDecode(login.body) as Map<String, dynamic>;
    expect(loginBody['refreshToken'], isA<String>());
    _expectTokenPair(loginBody, userId: 1, now: now);

    final register = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/register',
      jsonEncode({
        'username': 'newbie123',
        'password': 'Abc12345',
        'phone': '',
        'verifyCode': '',
      }),
    );
    expect(register.statusCode, 200);
    final registerBody = jsonDecode(register.body) as Map<String, dynamic>;
    expect(extractUserIdFromToken(registerBody['token'] as String), isNotNull);
    _expectTokenPair(registerBody, userId: null, now: now);
  });

  test('refresh 轮换新令牌对，重放旧 refreshToken 被拒绝', () {
    final login = jsonDecode(mock_router
        .dispatchResponse(
          'POST',
          '/api/v1/auth/login',
          jsonEncode({
            'username': 'xiaobaige',
            'password': mock_router.mockDevPassword,
            'loginType': 1,
          }),
        )
        .body) as Map<String, dynamic>;
    final firstRefresh = login['refreshToken'] as String;

    final rotated = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/refresh',
      jsonEncode({'refreshToken': firstRefresh}),
    );
    expect(rotated.statusCode, 200);
    final rotatedBody = jsonDecode(rotated.body) as Map<String, dynamic>;
    expect(rotatedBody['token'], isA<String>());
    expect(rotatedBody['refreshToken'], isA<String>());
    expect(rotatedBody['refreshToken'], isNot(firstRefresh));
    expect(extractUserIdFromToken(login['token'] as String), 1);
    expect(
      extractUserIdFromToken(rotatedBody['token'] as String),
      1,
    );

    final replay = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/refresh',
      jsonEncode({'refreshToken': firstRefresh}),
    );
    expect(replay.statusCode, 401);
    expect(jsonDecode(replay.body)['code'], 1005);
  });

  test('过期或无效的 refreshToken 按认证错误拒绝', () {
    final expired = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/refresh',
      jsonEncode({'refreshToken': mock_router.mockExpiredTokenForUser(1)}),
    );
    expect(expired.statusCode, 401);
    expect(jsonDecode(expired.body)['code'], 1004);

    final garbage = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/refresh',
      jsonEncode({'refreshToken': 'not-a-jwt'}),
    );
    expect(garbage.statusCode, 401);
    expect(jsonDecode(garbage.body)['code'], 1005);

    final missing = mock_router.dispatchResponse(
      'POST',
      '/api/v1/auth/refresh',
      '{}',
    );
    expect(missing.statusCode, 400);
  });
}

void _expectTokenPair(
  Map<String, dynamic> body, {
  required int? userId,
  required int now,
}) {
  final accessExp = extractExpiryFromToken(body['token'] as String);
  final refreshExp = extractExpiryFromToken(body['refreshToken'] as String);
  // access ~30 分钟，refresh ~7 天，允许测试执行耗时带来的少量偏差。
  expect(accessExp, greaterThan(now + 25 * 60));
  expect(accessExp, lessThanOrEqualTo(now + 30 * 60));
  expect(refreshExp, greaterThan(now + 6 * 24 * 60 * 60));
  if (userId != null) {
    expect(extractUserIdFromToken(body['token'] as String), userId);
    expect(extractUserIdFromToken(body['refreshToken'] as String), userId);
  }
}
