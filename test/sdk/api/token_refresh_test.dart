import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    onSessionInvalid = null;
  });

  tearDown(() {
    onSessionInvalid = null;
  });

  test('认证失败时换发令牌并恰好重试一次', () async {
    var protectedCalls = 0;
    var refreshCalls = 0;
    final authHeaders = <String?>[];
    final client = _ScriptedClient((request) async {
      if (request.url.path.endsWith('/api/v1/auth/refresh')) {
        refreshCalls++;
        final body =
            jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        expect(body['refreshToken'], 'refresh-1');
        return _jsonResponse({
          'token': 'access-2',
          'refreshToken': 'refresh-2',
        }, 200);
      }
      protectedCalls++;
      authHeaders.add(request.headers['Authorization']);
      if (protectedCalls == 1) {
        return _jsonResponse({'code': 1004, 'message': 'token 已过期'}, 401);
      }
      return _jsonResponse({'items': <Object>[]}, 200);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ));

    Object? okPayload;
    await apiGet(
      '/api/v1/posts',
      ok: (data) => okPayload = data,
      fail: (error) => fail('unexpected failure: $error'),
    );

    expect(okPayload, isNotNull);
    expect(protectedCalls, 2);
    expect(refreshCalls, 1);
    expect(authHeaders, ['Bearer access-1', 'Bearer access-2']);

    final stored = await getTokens();
    expect(stored?.accessToken, 'access-2');
    expect(stored?.refreshToken, 'refresh-2');
  });

  test('并发认证失败只触发一次换发', () async {
    final refreshGate = Completer<void>();
    var protectedCalls = 0;
    var refreshCalls = 0;
    final client = _ScriptedClient((request) async {
      if (request.url.path.endsWith('/api/v1/auth/refresh')) {
        refreshCalls++;
        await refreshGate.future;
        return _jsonResponse({
          'token': 'access-2',
          'refreshToken': 'refresh-2',
        }, 200);
      }
      protectedCalls++;
      // 换发完成前的请求一律 401，完成后的重试放行，验证两个请求都重试成功。
      if (refreshCalls == 0) {
        return _jsonResponse({'code': 1005, 'message': '无效令牌'}, 401);
      }
      return _jsonResponse({'ok': true}, 200);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ));

    final first = apiGet('/api/v1/a', ok: (_) {}, fail: (_) {});
    final second = apiGet('/api/v1/b', ok: (_) {}, fail: (_) {});
    await Future<void>.delayed(Duration.zero);
    refreshGate.complete();
    await Future.wait([first, second]);

    expect(refreshCalls, 1);
    // 单飞换发：每个原始请求各自"初次 401 + 重试成功"，共 4 次命中。
    expect(protectedCalls, 4);
    final stored = await getTokens();
    expect(stored?.accessToken, 'access-2');
  });

  test('换发被网关拒绝时清空会话并触发 onSessionInvalid', () async {
    var sessionInvalidated = false;
    onSessionInvalid = () async {
      sessionInvalidated = true;
    };
    var refreshCalls = 0;
    final client = _ScriptedClient((request) async {
      if (request.url.path.endsWith('/api/v1/auth/refresh')) {
        refreshCalls++;
        return _jsonResponse({'code': 1005, 'message': '登录状态无效'}, 401);
      }
      return _jsonResponse({'code': 1006, 'message': '请先登录'}, 401);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ));

    String? failure;
    await apiGet(
      '/api/v1/posts',
      ok: (data) => fail('unexpected success: $data'),
      fail: (error) => failure = error,
    );

    expect(failure, isNotNull);
    expect(refreshCalls, 1);
    expect(sessionInvalidated, isTrue);
    expect(await getTokens(), isNull);
  });

  test('没有 refreshToken 时直接失败，不发起换发', () async {
    var refreshCalls = 0;
    final client = _ScriptedClient((request) async {
      if (request.url.path.endsWith('/api/v1/auth/refresh')) {
        refreshCalls++;
        return _jsonResponse({}, 200);
      }
      return _jsonResponse({'code': 1004, 'message': 'token 已过期'}, 401);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(accessToken: 'access-1', refreshToken: ''));

    String? failure;
    await apiGet(
      '/api/v1/posts',
      ok: (data) => fail('unexpected success: $data'),
      fail: (error) => failure = error,
    );

    expect(failure, isNotNull);
    expect(refreshCalls, 0);
    final stored = await getTokens();
    expect(stored?.accessToken, 'access-1');
  });

  test('非认证错误不触发换发', () async {
    var refreshCalls = 0;
    final client = _ScriptedClient((request) async {
      if (request.url.path.endsWith('/api/v1/auth/refresh')) {
        refreshCalls++;
        return _jsonResponse({}, 200);
      }
      return _jsonResponse({'code': 1003, 'message': '密码错误'}, 401);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ));

    String? failure;
    await apiPost(
      '/api/v1/auth/login',
      {'username': 'a', 'password': 'b', 'loginType': 1},
      ok: (data) => fail('unexpected success: $data'),
      fail: (error) => failure = error,
    );

    expect(failure, isNotNull);
    expect(refreshCalls, 0);
  });

  test('网络异常不换发成功也不清空会话', () async {
    var sessionInvalidated = false;
    onSessionInvalid = () async {
      sessionInvalidated = true;
    };
    final client = _ScriptedClient((request) async {
      throw http.ClientException('network down', request.url);
    });
    setApiClient(client);
    await setTokens(buildStoredTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    ));

    String? failure;
    await apiGet(
      '/api/v1/posts',
      ok: (data) => fail('unexpected success: $data'),
      fail: (error) => failure = error,
    );

    expect(failure, isNotNull);
    expect(sessionInvalidated, isFalse);
    final stored = await getTokens();
    expect(stored?.accessToken, 'access-1');
  });
}

class _ScriptedClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) handler;

  _ScriptedClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}

http.StreamedResponse _jsonResponse(Object body, int status) {
  return http.StreamedResponse(
    Stream.value(utf8.encode(jsonEncode(body))),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}
