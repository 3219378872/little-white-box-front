import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/api/api_adapter.dart' as api_adapter;
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart' as sdk_api;
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('onLoginSuccess 持久化双令牌并解出有效期', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await pumpEventQueue();

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final accessExp = now + 30 * 60;
    final refreshExp = now + 7 * 24 * 60 * 60;

    await notifier.onLoginSuccess(
      7,
      _jwt(userId: 7, exp: accessExp),
      refreshToken: _jwt(userId: 7, exp: refreshExp),
    );

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.userId, 7);

    final stored = await getTokens();
    expect(stored?.accessToken, _jwt(userId: 7, exp: accessExp));
    expect(stored?.refreshToken, _jwt(userId: 7, exp: refreshExp));
    expect(stored?.accessExpire, accessExp);
    expect(stored?.refreshExpire, refreshExp);
  });

  test('onLoginSuccess 兼容缺失 refreshToken 的旧网关响应', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await pumpEventQueue();

    await notifier.onLoginSuccess(7, _jwt(userId: 7, exp: 0));

    final stored = await getTokens();
    expect(stored?.accessToken, isNotEmpty);
    expect(stored?.refreshToken, isEmpty);
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
  });

  test('onSessionExpired 清空内存态与持久化令牌并通知监听', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    await pumpEventQueue();

    var notifications = 0;
    notifier.listenable.addListener(() => notifications++);

    await notifier.onLoginSuccess(
      7,
      _jwt(userId: 7, exp: 0),
      refreshToken: 'refresh-token',
    );
    expect(notifications, 1);

    await notifier.onSessionExpired();

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.token, isNull);
    expect(await getTokens(), isNull);
    expect(notifications, 2);
  });

  test('传输层 onAuthError 绑定会话重置（无 refreshToken 死区路径）', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    container.read(authTransportBindingProvider);
    await pumpEventQueue();

    // 无 refreshToken：请求失败只走 adapter 的 onAuthError，不经过 SDK 刷新。
    await notifier.onLoginSuccess(7, _jwt(userId: 7, exp: 0));
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

    await api_adapter.onAuthError?.call();
    await pumpEventQueue();

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(await getTokens(), isNull);
  });

  test('SDK 刷新被拒的 onSessionInvalid 同样重置会话', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    container.read(authTransportBindingProvider);
    await pumpEventQueue();

    await notifier.onLoginSuccess(
      7,
      _jwt(userId: 7, exp: 0),
      refreshToken: 'refresh-token',
    );
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

    sdk_api.onSessionInvalid?.call();
    await pumpEventQueue();

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(await getTokens(), isNull);
  });
}

String _jwt({required int userId, required int exp}) {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = segment({'alg': 'none', 'typ': 'JWT'});
  final payload =
      exp > 0 ? segment({'userId': userId, 'exp': exp}) : segment({
        'userId': userId,
      });
  return '$header.$payload.sig';
}
