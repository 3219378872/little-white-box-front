import 'dart:convert';

import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_dependencies.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/auth/data/auth_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart' as sdk_api;
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

// 固定返回同一账号的登录/注册响应，并记录验证码请求。
class _FakeAuthRepository extends AuthRepository {
  final List<(String, int)> codes = [];

  @override
  Future<LoginResp> loginWithPassword(String username, String password) async {
    return LoginResp(userId: 7, token: 'access-7', refreshToken: 'refresh-7');
  }

  @override
  Future<RegisterResp> registerUser({
    required String username,
    required String password,
    required String phone,
    required String verifyCode,
  }) async {
    return RegisterResp(userId: 8, token: 'access-8', refreshToken: '');
  }

  @override
  Future<SendVerifyCodeResp> sendCode(String phone, int type) async {
    codes.add((phone, type));
    return SendVerifyCodeResp();
  }
}

typedef _AuthHarness = ({
  ProviderContainer container,
  _FakeAuthRepository repository,
});

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => sdk_api.onSessionInvalid = null);

  group('auth commands', () {
    _AuthHarness create() {
      final repository = _FakeAuthRepository();
      final container = createAppProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);
      return (container: container, repository: repository);
    }

    test('login starts a session only while the page is current', () async {
      final (:container, repository: _) = create();
      final notifier = container.read(authNotifierProvider.notifier);
      await pumpEventQueue();

      final stale = await notifier.loginWithPassword(
        'neo',
        'secret',
        isCurrent: () => false,
      );
      expect(stale, isFalse);
      expect(container.read(authNotifierProvider).isAuthenticated, isFalse);

      final started = await notifier.loginWithPassword(
        'neo',
        'secret',
        isCurrent: () => true,
      );
      expect(started, isTrue);
      final state = container.read(authNotifierProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.token, 'access-7');
    });

    test('register signs in as the new account', () async {
      final (:container, repository: _) = create();
      final notifier = container.read(authNotifierProvider.notifier);
      await pumpEventQueue();

      final started = await notifier.register(
        username: 'neo',
        password: 'secret',
        phone: '13800000000',
        verifyCode: '123456',
        isCurrent: () => true,
      );

      expect(started, isTrue);
      expect(container.read(authNotifierProvider).userId, 8);
    });

    test('verify codes carry the gateway purpose type', () async {
      final (:container, :repository) = create();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.sendVerifyCode('138', VerifyCodePurpose.register);
      await notifier.sendVerifyCode('139', VerifyCodePurpose.login);

      expect(repository.codes, [('138', 1), ('139', 2)]);
    });
  });

  test('onLoginSuccess 持久化双令牌并解出有效期', () async {
    final container = createAppProviderContainer();
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
    final container = createAppProviderContainer();
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
    final container = createAppProviderContainer();
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

    final snapshot = await getTokenSnapshot();
    expect(snapshot, isNotNull);
    await notifier.onSessionExpired(snapshot!);

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.token, isNull);
    expect(await getTokens(), isNull);
    expect(notifications, 2);
  });

  test('传输层按请求快照绑定会话重置（无 refreshToken 路径）', () async {
    final container = createAppProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    container.read(authTransportBindingProvider);
    await pumpEventQueue();

    // 无 refreshToken：最终认证失败由 SDK 按发起请求的凭据条件删除。
    await notifier.onLoginSuccess(7, _jwt(userId: 7, exp: 0));
    expect(container.read(authNotifierProvider).isAuthenticated, isTrue);

    final snapshot = await getTokenSnapshot();
    await sdk_api.invalidateSessionIfCredentialsMatch(snapshot!);
    await pumpEventQueue();

    expect(container.read(authNotifierProvider).isAuthenticated, isFalse);
    expect(await getTokens(), isNull);
  });

  test('迟到的旧会话失效通知不能清除后来登录的账号', () async {
    final container = createAppProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);
    container.read(authTransportBindingProvider);
    await pumpEventQueue();

    await notifier.onLoginSuccess(
      7,
      _jwt(userId: 7, exp: 0),
      refreshToken: 'refresh-token-a',
    );
    final oldSnapshot = await getTokenSnapshot();
    await notifier.onLoginSuccess(
      8,
      _jwt(userId: 8, exp: 0),
      refreshToken: 'refresh-token-b',
    );

    await sdk_api.onSessionInvalid?.call(oldSnapshot!);
    await pumpEventQueue();

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.userId, 8);
    expect((await getTokens())?.refreshToken, 'refresh-token-b');
  });

  test('初始化恢复排在立即登录之前，旧会话不能覆盖新登录', () async {
    SharedPreferences.setMockInitialValues({
      'tokens': jsonEncode({
        'access_token': _jwt(userId: 7, exp: 0),
        'access_expire': 0,
        'refresh_token': 'refresh-token-old',
        'refresh_expire': 0,
        'refresh_after': 0,
        'session_revision': 4,
      }),
      'tokens.session_revision': 4,
    });
    final container = createAppProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);

    await notifier.onLoginSuccess(
      8,
      _jwt(userId: 8, exp: 0),
      refreshToken: 'refresh-token-new',
    );

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isTrue);
    expect(state.userId, 8);
    expect(state.sessionRevision, 5);
    expect((await getTokens())?.refreshToken, 'refresh-token-new');
  });

  test('未等待登录完成就登出时，调用顺序决定最终为匿名会话', () async {
    final container = createAppProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authNotifierProvider.notifier);

    final login = notifier.onLoginSuccess(
      7,
      _jwt(userId: 7, exp: 0),
      refreshToken: 'refresh-token',
    );
    final logout = notifier.logout();
    await Future.wait([login, logout]);

    final state = container.read(authNotifierProvider);
    expect(state.isAuthenticated, isFalse);
    expect(state.userId, isNull);
    expect(state.sessionRevision, 2);
    expect(await getTokens(), isNull);
  });
}

String _jwt({required int userId, required int exp}) {
  String segment(Object json) =>
      base64Url.encode(utf8.encode(jsonEncode(json))).replaceAll('=', '');
  final header = segment({'alg': 'none', 'typ': 'JWT'});
  final payload = exp > 0
      ? segment({'userId': userId, 'exp': exp})
      : segment({'userId': userId});
  return '$header.$payload.sig';
}
