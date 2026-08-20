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
}
