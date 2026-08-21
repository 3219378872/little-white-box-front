import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sdk/vars/kv.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/auth/jwt_decoder.dart';
import '../../../core/auth/session_tokens.dart';

class AuthState {
  final bool isAuthenticated;
  final Object? userId;
  final String? token;
  final bool isLoading;

  const AuthState({
    this.isAuthenticated = false,
    this.userId,
    this.token,
    this.isLoading = true,
  });

  AuthState copyWith({
    bool? isAuthenticated,
    Object? userId,
    String? token,
    bool? isLoading,
  }) {
    return AuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// GoRouter 需要 Listenable 来监听认证状态变化
class AuthChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthChangeNotifier _changeNotifier;

  AuthNotifier(this._changeNotifier) : super(const AuthState()) {
    _init();
  }

  AuthChangeNotifier get listenable => _changeNotifier;

  Future<void> _init() async {
    final tokens = await getTokens();
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      final userId = extractUserIdFromToken(tokens.accessToken);
      if (userId == null || !jsonInt64IsPositive(userId)) {
        // token 异常：清掉，按未登录处理
        await removeTokens();
        state = const AuthState(isLoading: false);
      } else {
        state = AuthState(
          isAuthenticated: true,
          userId: userId,
          token: tokens.accessToken,
          isLoading: false,
        );
      }
    } else {
      state = const AuthState(isLoading: false);
    }
    _changeNotifier.notify();
  }

  Future<void> onLoginSuccess(
    Object userId,
    String token, {
    String refreshToken = '',
  }) async {
    await setTokens(buildStoredTokens(
      accessToken: token,
      refreshToken: refreshToken,
    ));
    state = AuthState(
      isAuthenticated: true,
      userId: userId,
      token: token,
      isLoading: false,
    );
    _changeNotifier.notify();
  }

  Future<void> logout() => _resetSession();

  /// 刷新令牌被网关拒绝后的会话清理，由传输层 onSessionInvalid 触发。
  Future<void> onSessionExpired() => _resetSession();

  Future<void> _resetSession() async {
    await removeTokens();
    state = const AuthState(isLoading: false);
    _changeNotifier.notify();
  }
}

final _authChangeNotifierProvider = Provider((ref) => AuthChangeNotifier());

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(_authChangeNotifierProvider));
});

/// 供 GoRouter refreshListenable 使用
final authListenableProvider = Provider<AuthChangeNotifier>((ref) {
  return ref.read(_authChangeNotifierProvider);
});
