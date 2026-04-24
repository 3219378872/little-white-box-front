import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';

void main() {
  group('ApiException', () {
    test('基本构造：只有 message', () {
      const e = ApiException('网络错误');
      expect(e.message, '网络错误');
      expect(e.code, isNull);
      expect(e.toString(), '网络错误');
    });

    test('带 code 构造', () {
      const e = ApiException('密码错误', code: 1003);
      expect(e.message, '密码错误');
      expect(e.code, 1003);
      expect(e.toString(), '密码错误');
    });

    test('parse: 有效 JSON 字符串', () {
      final raw = jsonEncode({'code': 1001, 'message': '用户不存在'});
      final e = ApiException.parse(raw);
      expect(e.code, 1001);
      expect(e.message, '用户不存在');
    });

    test('parse: JSON 无 code 字段', () {
      final raw = jsonEncode({'message': '未知错误'});
      final e = ApiException.parse(raw);
      expect(e.code, isNull);
      expect(e.message, '未知错误');
    });

    test('parse: 非 JSON 字符串回退为 message', () {
      final e = ApiException.parse('plain error text');
      expect(e.code, isNull);
      expect(e.message, 'plain error text');
    });

    test('parse: 空字符串', () {
      final e = ApiException.parse('');
      expect(e.code, isNull);
      expect(e.message, '');
    });

    test('isAuthError: code 1004/1005/1006 返回 true', () {
      expect(const ApiException('', code: 1004).isAuthError, isTrue);
      expect(const ApiException('', code: 1005).isAuthError, isTrue);
      expect(const ApiException('', code: 1006).isAuthError, isTrue);
    });

    test('isAuthError: 其他 code 返回 false', () {
      expect(const ApiException('', code: 1001).isAuthError, isFalse);
      expect(const ApiException('', code: 1003).isAuthError, isFalse);
      expect(const ApiException('').isAuthError, isFalse);
    });
  });
}
