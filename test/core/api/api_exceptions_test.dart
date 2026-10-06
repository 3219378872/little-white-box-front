import 'dart:async';
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

    test('parse: 非 JSON 文本是客户端异常，按类别换成中文并保留原文', () {
      final network = ApiException.parse('ClientException: Connection refused');
      expect(network.code, isNull);
      expect(network.message, '网络连接失败，请检查网络后重试');
      expect(network.detail, 'ClientException: Connection refused');

      final decode = ApiException.parse(
        "type 'int' is not a subtype of type 'String' in type cast",
      );
      expect(decode.message, '服务返回了无法识别的数据');
      expect(decode.detail, contains('type cast'));
    });

    test('parse: 空字符串视为无法识别的响应', () {
      final e = ApiException.parse('');
      expect(e.code, isNull);
      expect(e.message, '服务返回了无法识别的数据');
    });

    test('parse: 无业务码的英文 HTTP 失败换成中文', () {
      ApiException parse(String message) =>
          ApiException.parse(jsonEncode({'code': null, 'message': message}));

      expect(parse('http 502').message, '请求失败，请稍后重试（HTTP 502）');
      expect(parse('http 401').message, '登录已失效，请重新登录');
      final page = parse('<html>502 Bad Gateway</html>');
      expect(page.message, '请求失败，请稍后重试');
      expect(page.detail, '<html>502 Bad Gateway</html>');
    });

    test('parse: 有业务码或中文文案时原样保留', () {
      final business = ApiException.parse(
        jsonEncode({'code': 6, 'message': 'unavailable'}),
      );
      expect(business.message, 'unavailable');
      expect(business.code, 6);
      expect(
        ApiException.parse(jsonEncode({'message': '会话刷新失败，请重试'})).message,
        '会话刷新失败，请重试',
      );
    });

    test('fromClientError: 已是 ApiException 时原样返回，超时单独提示', () {
      const original = ApiException('已有文案', code: 2001);
      expect(ApiException.fromClientError(original), same(original));
      expect(
        ApiException.fromClientError(TimeoutException('slow')).message,
        '请求超时，请重试',
      );
      expect(
        ApiException.fromClientError(const FormatException('missing list'))
            .message,
        '服务返回了无法识别的数据',
      );
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

  group('friendlyErrorMessage', () {
    test('ApiException 直接返回 message', () {
      const e = ApiException('密码错误', code: 1003);
      expect(friendlyErrorMessage(e), '密码错误');
    });

    test('普通 Exception 去掉前缀', () {
      expect(friendlyErrorMessage(Exception('网络超时')), '网络超时');
    });

    test('非 Exception 对象返回 toString', () {
      expect(friendlyErrorMessage('some error'), 'some error');
    });
  });
}
