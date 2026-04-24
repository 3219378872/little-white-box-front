import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';

void main() {
  group('apiCall', () {
    test('ok 回调正常返回数据', () async {
      final result = await apiCall<String>(
        (ok, fail, eventually) {
          ok('hello');
          eventually();
        },
      );
      expect(result, 'hello');
    });

    test('fail 回调带 JSON 字符串时解析出 code 和 message', () async {
      try {
        await apiCall<String>(
          (ok, fail, eventually) {
            fail(jsonEncode({'code': 1003, 'message': '密码错误'}));
            eventually();
          },
        );
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.code, 1003);
        expect(e.message, '密码错误');
      }
    });

    test('fail 回调带普通字符串时 code 为 null', () async {
      try {
        await apiCall<String>(
          (ok, fail, eventually) {
            fail('plain error');
            eventually();
          },
        );
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.code, isNull);
        expect(e.message, 'plain error');
      }
    });

    test('eventually 在未完成时抛出默认错误', () async {
      try {
        await apiCall<String>(
          (ok, fail, eventually) {
            eventually();
          },
        );
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.message, '请求未返回结果');
      }
    });
  });

  group('apiCallWithTimeout', () {
    test('超时抛出 ApiException', () async {
      try {
        await apiCallWithTimeout<String>(
          (ok, fail, eventually) {
            // 不调用任何回调，模拟挂起
          },
          timeout: const Duration(milliseconds: 100),
        );
        fail('should have thrown');
      } on ApiException catch (e) {
        expect(e.message, '请求超时');
      }
    });
  });
}
