import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/auth/jwt_decoder.dart';

/// 构造一个用于测试的最小 JWT：header.payload.sig
String _buildJwt(Map<String, dynamic> payload) {
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final payloadStr = base64Url
      .encode(utf8.encode(jsonEncode(payload)))
      .replaceAll('=', '');
  return '$header.$payloadStr.fake-sig';
}

void main() {
  group('decodeJwtPayload', () {
    test('解析正常 token 返回 payload map', () {
      final token = _buildJwt({'userId': 42, 'name': 'alice'});
      final payload = decodeJwtPayload(token);
      expect(payload, isNotNull);
      expect(payload!['userId'], 42);
      expect(payload['name'], 'alice');
    });

    test('两段式 token 返回 null', () {
      expect(decodeJwtPayload('header.payload'), isNull);
    });

    test('四段式 token 返回 null', () {
      expect(decodeJwtPayload('a.b.c.d'), isNull);
    });

    test('payload 不是合法 JSON 返回 null', () {
      final bogus = base64Url
          .encode(utf8.encode('not-json'))
          .replaceAll('=', '');
      expect(decodeJwtPayload('header.$bogus.sig'), isNull);
    });

    test('payload 是 JSON 数组返回 null', () {
      final arr = base64Url
          .encode(utf8.encode('[1,2,3]'))
          .replaceAll('=', '');
      expect(decodeJwtPayload('header.$arr.sig'), isNull);
    });

    test('base64url 需要 padding 的 token 能正常解析', () {
      final token = _buildJwt({'userId': 1});
      expect(decodeJwtPayload(token), isNotNull);
    });

    test('空字符串返回 null', () {
      expect(decodeJwtPayload(''), isNull);
    });
  });

  group('extractUserIdFromToken', () {
    test('payload 含 userId 返回数值', () {
      final token = _buildJwt({'userId': 123});
      expect(extractUserIdFromToken(token), 123);
    });

    test('payload 无 userId 返回 null', () {
      final token = _buildJwt({'name': 'alice'});
      expect(extractUserIdFromToken(token), isNull);
    });

    test('token 解析失败返回 null', () {
      expect(extractUserIdFromToken('garbage'), isNull);
    });
  });
}
