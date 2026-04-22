import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sdk/data/tokens.dart';
import '../../../sdk/vars/kv.dart';
import '../../../core/auth/jwt_decoder.dart';

class AuthState {
  final bool isAuthenticated;
  final num? userId;
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
    num? userId,
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
      if (userId == null || userId <= 0) {
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

  Future<void> onLoginSuccess(num userId, String token) async {
    final tokens = Tokens(
      accessToken: token,
      accessExpire: 0,
      refreshToken: '',
      refreshExpire: 0,
      refreshAfter: 0,
    );
    await setTokens(tokens);
    state = AuthState(
      isAuthenticated: true,
      userId: userId,
      token: token,
      isLoading: false,
    );
    _changeNotifier.notify();
  }

  Future<void> logout() async {
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
