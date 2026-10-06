import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../sdk/vars/kv.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/auth/jwt_decoder.dart';
import '../../../core/auth/session_tokens.dart';
import '../../../sdk/api/api.dart' as sdk_api;
import '../data/auth_repository.dart';
import 'auth_dependencies.dart';

class AuthState {
  final bool isAuthenticated;
  final Object? userId;
  final String? token;
  final bool isLoading;
  final int sessionRevision;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.token,
    this.isLoading = true,
    this.sessionRevision = 0,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    Object? userId,
    String? token,
    bool? isLoading,
    int? sessionRevision,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
      sessionRevision: sessionRevision ?? this.sessionRevision,
    );
  }
}

/// GoRouter 需要 Listenable 来监听认证状态变化
class AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

/// 验证码用途，取值与网关 `SendVerifyCodeReq.type` 一致。
enum VerifyCodePurpose {
  register(1),
  login(2);

  final int wireType;
  const VerifyCodePurpose(this.wireType);
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthChangeNotifier _changeNotifier;
  final AuthRepository _repository;
  Future<void> _operationTail = Future<void>.value();

  AuthNotifier(this._changeNotifier, {AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(const AuthState()) {
    unawaited(_serialize(_restoreSession));
  }

  AuthChangeNotifier get listenable => _changeNotifier;

  Future<void> _restoreSession() async {
    final snapshot = await getTokenSnapshot();
    final tokens = snapshot?.tokens;
    if (snapshot != null && tokens != null && tokens.accessToken.isNotEmpty) {
      final userId = extractUserIdFromToken(tokens.accessToken);
      if (userId == null || !jsonInt64IsPositive(userId)) {
        await removeTokensIfCredentialsMatch(snapshot);
        _publish(
          AuthState(
            isLoading: false,
            sessionRevision: await getTokenSessionRevision(),
          ),
        );
      } else {
        _publish(
          AuthState(
            isAuthenticated: true,
            userId: userId,
            token: tokens.accessToken,
            isLoading: false,
            sessionRevision: snapshot.revision,
          ),
        );
      }
    } else {
      _publish(
        AuthState(
          isLoading: false,
          sessionRevision: await getTokenSessionRevision(),
        ),
      );
    }
  }

  Future<void> onLoginSuccess(
    Object userId,
    String token, {
    String refreshToken = '',
  }) {
    return _serialize(() async {
      final snapshot = await startTokenSession(
        buildStoredTokens(accessToken: token, refreshToken: refreshToken),
      );
      _publish(
        AuthState(
          isAuthenticated: true,
          userId: userId,
          token: token,
          isLoading: false,
          sessionRevision: snapshot.revision,
        ),
      );
    });
  }

  /// 用户名密码登录；返回是否已开启新会话。
  ///
  /// [isCurrent] 在登录响应返回后复核发起页面仍在前台：用户已离开时迟到的成功响应
  /// 不得替换当前会话。
  Future<bool> loginWithPassword(
    String username,
    String password, {
    required bool Function() isCurrent,
  }) async {
    final resp = await _repository.loginWithPassword(username, password);
    return _startSessionIfCurrent(
      resp.userId,
      resp.token,
      resp.refreshToken,
      isCurrent,
    );
  }

  /// 手机验证码登录；迟到响应的处理同 [loginWithPassword]。
  Future<bool> loginWithVerifyCode(
    String phone,
    String code, {
    required bool Function() isCurrent,
  }) async {
    final resp = await _repository.loginWithVerifyCode(phone, code);
    return _startSessionIfCurrent(
      resp.userId,
      resp.token,
      resp.refreshToken,
      isCurrent,
    );
  }

  /// 注册并直接以新账号登录；迟到响应的处理同 [loginWithPassword]。
  Future<bool> register({
    required String username,
    required String password,
    required String phone,
    required String verifyCode,
    required bool Function() isCurrent,
  }) async {
    final resp = await _repository.registerUser(
      username: username,
      password: password,
      phone: phone,
      verifyCode: verifyCode,
    );
    return _startSessionIfCurrent(
      resp.userId,
      resp.token,
      resp.refreshToken,
      isCurrent,
    );
  }

  /// 向 [phone] 发送指定用途的短信验证码。
  Future<void> sendVerifyCode(String phone, VerifyCodePurpose purpose) {
    return _repository.sendCode(phone, purpose.wireType);
  }

  // 认证接口成功后，只有发起页面仍是当前页面才写入令牌并开启会话。
  Future<bool> _startSessionIfCurrent(
    Object userId,
    String token,
    String refreshToken,
    bool Function() isCurrent,
  ) async {
    if (!isCurrent()) return false;
    await onLoginSuccess(userId, token, refreshToken: refreshToken);
    return true;
  }

  Future<void> logout() => _serialize(_resetSession);

  /// Only clears the in-memory identity that owned the rejected credentials.
  Future<void> onSessionExpired(SessionTokenSnapshot expired) {
    return _serialize(() async {
      if (state.sessionRevision != expired.revision) return;
      final current = await getTokenSnapshot();
      if (current != null && !await removeTokensIfCredentialsMatch(expired)) {
        return;
      }
      _publish(
        AuthState(
          isLoading: false,
          sessionRevision: await getTokenSessionRevision(),
        ),
      );
    });
  }

  Future<void> _resetSession() async {
    await removeTokens();
    _publish(
      AuthState(
        isLoading: false,
        sessionRevision: await getTokenSessionRevision(),
      ),
    );
  }

  void _publish(AuthState next) {
    if (!mounted) return;
    state = next;
    _changeNotifier.notify();
  }

  Future<void> _serialize(Future<void> Function() operation) {
    final completer = Completer<void>();
    _operationTail = _operationTail.then((_) async {
      try {
        await operation();
        completer.complete();
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

final _authChangeNotifierProvider = Provider((ref) => AuthChangeNotifier());

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(
    ref.read(_authChangeNotifierProvider),
    repository: ref.read(authRepositoryProvider),
  );
});

/// 供 GoRouter refreshListenable 使用
final authListenableProvider = Provider<AuthChangeNotifier>((ref) {
  return ref.read(_authChangeNotifierProvider);
});

/// Stable cache boundary for public and authenticated feature state. Access
/// token rotation preserves the revision; login, logout, and account switches
/// advance it.
final authSessionIdentityProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth.isAuthenticated && jsonInt64IsPositive(auth.userId ?? 0)) {
    return 'user:${jsonInt64Id(auth.userId!)}:${auth.sessionRevision}';
  }
  return 'anonymous:${auth.sessionRevision}';
});

final authenticatedSessionIdentityProvider = Provider<String?>((ref) {
  final auth = ref.watch(authNotifierProvider);
  if (auth.isLoading ||
      !auth.isAuthenticated ||
      !jsonInt64IsPositive(auth.userId ?? 0)) {
    return null;
  }
  return 'user:${jsonInt64Id(auth.userId!)}:${auth.sessionRevision}';
});

/// 把传输层认证失败回调统一绑定到会话重置
/// （DES-flutter-client「会话与令牌刷新」：宿主用它同步 AuthNotifier 内存态，
/// 由 refreshListenable 把受保护页面重定向到登录页）。
///
/// 覆盖两条路径：SDK 刷新被拒后的 `onSessionInvalid`，以及无 refreshToken、
/// multipart 上传与 Assistant SSE 等直连路径的 `onAuthError`。回调幂等，
/// 重复触发只多做一次清理。由应用壳 watch 一次完成装配。
final authTransportBindingProvider = Provider((ref) {
  Future<void> resetSession(SessionTokenSnapshot expired) {
    return ref.read(authNotifierProvider.notifier).onSessionExpired(expired);
  }

  sdk_api.onSessionInvalid = resetSession;
});
