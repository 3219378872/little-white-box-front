import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';

String jwtWithExp(int exp) {
  String part(Map<String, dynamic> json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.signature';
}

void main() {
  test('builds a persisted session with expiries decoded from both JWTs',
      () {
    final tokens = buildStoredTokens(
      accessToken: jwtWithExp(1700000100),
      refreshToken: jwtWithExp(1700009900),
    );

    expect(tokens.accessToken, jwtWithExp(1700000100));
    expect(tokens.accessExpire, 1700000100);
    expect(tokens.refreshToken, jwtWithExp(1700009900));
    expect(tokens.refreshExpire, 1700009900);
    // 刷新决策只看 refreshToken 是否存在，refreshAfter 恒为 0。
    expect(tokens.refreshAfter, 0);
  });

  test('records unknown expiries as 0 for non-JWT input', () {
    final tokens = buildStoredTokens(
      accessToken: 'opaque-access',
      refreshToken: 'opaque-refresh',
    );

    expect(tokens.accessExpire, 0);
    expect(tokens.refreshExpire, 0);
  });
}
