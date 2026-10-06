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

/// 内存中的登录态快照。
///
/// [isLoading] 只在启动恢复会话前为 true；[sessionRevision] 与本地令牌存储的会话版本
/// 对应，登录、登出与换号都会推进，用来让迟到的请求结果识别出自己属于旧会话。
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

/// 应用唯一的会话状态持有者：启动时从本地令牌恢复会话，登录/注册成功后写入令牌，
/// 登出或传输层判定凭据失效时清理。所有会话变更串行执行，并在发布新状态时通知路由刷新。
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthChangeNotifier _changeNotifier;
  final AuthRepository _repository;
  Future<void> _operationTail = Future<void>.value();

  AuthNotifier(this._changeNotifier, {AuthRepository? repository})
    : _repository = repository ?? AuthRepository(),
      super(const AuthState()) {
    unawaited(_serialize(_restoreSession));
  }

  /// 路由刷新用的监听对象。
  AuthChangeNotifier get listenable => _changeNotifier;

  // 冷启动恢复：本地访问令牌能解出有效 userId 则视为已登录（不做网络校验），
  // 否则清掉坏令牌并以匿名态结束加载。
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

  /// 以新令牌对开启会话：写入本地存储并推进会话版本，再发布已登录状态。
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

  /// 主动登出：清除本地令牌并回到匿名态。
  Future<void> logout() => _serialize(_resetSession);

  /// Only clears the in-memory identity that owned the rejected credentials.
  Future<void> onSessionExpired(SessionTokenSnapshot expired) {
    return _serialize(() async {
      // 内存态已属于后来的会话，或本地已换成别的凭据时，忽略这次过期通知。
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

  // 无条件清除令牌；会话版本由存储层推进。
  Future<void> _resetSession() async {
    await removeTokens();
    _publish(
      AuthState(
        isLoading: false,
        sessionRevision: await getTokenSessionRevision(),
      ),
    );
  }

  // notifier 已销毁时丢弃；否则更新状态并通知 GoRouter 重新评估重定向。
  void _publish(AuthState next) {
    if (!mounted) return;
    state = next;
    _changeNotifier.notify();
  }

  // 把会话操作挂到同一条队尾依次执行，避免恢复、登录与登出交错写令牌；
  // 单个操作失败只反馈给它的调用方，不阻断后续操作。
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

/// 全局会话状态。
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

/// 仅已登录时非空的会话身份，供需要登录的 feature 状态在换号或登出时重建；
/// 会话恢复中与匿名时为 null。
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
/// 覆盖两条路径：SDK 刷新被拒，以及无法刷新时 multipart 上传、Assistant SSE 等
/// 直连路径调用的 `invalidateSessionIfCredentialsMatch`；两者都经 `onSessionInvalid`
/// 回调到这里。回调幂等，重复触发只多做一次清理。由应用壳 watch 一次完成装配。
final authTransportBindingProvider = Provider((ref) {
  Future<void> resetSession(SessionTokenSnapshot expired) {
    return ref.read(authNotifierProvider.notifier).onSessionExpired(expired);
  }

  sdk_api.onSessionInvalid = resetSession;
});
