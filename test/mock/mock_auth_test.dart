import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../lib/core/auth/jwt_decoder.dart';
import '../../lib/mock/mock_router.dart' as mock_router;
import '../../lib/sdk/api/api.dart';

void main() {
  test('Mock login returns the default user and a usable token', () async {
    final envelope = jsonDecode(mock_router.dispatch(
      'POST',
      '/api/v1/auth/login',
      '{"username":"anything","password":"anything"}',
    ));
    final response = apiResponseData(envelope);

    expect(response['userId'], 1);
    final token = response['token'] as String?;
    expect(token, isNotEmpty);
    expect(extractUserIdFromToken(token!), 1);
  });
}
