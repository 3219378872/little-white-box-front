import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'sdk/api/api.dart';
import 'sdk/data/tokens.dart';
import 'sdk/vars/kv.dart';
import 'mock/mock_http.dart';
import 'mock/mock_router.dart' as mock_router;

/// Mock 模式入口
///
/// 使用方式：flutter run -d web-server -t lib/main_mock.dart
/// 所有 HTTP 请求将被拦截并返回内存中的 Mock 数据
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setApiClient(MockHttpClient());

  // Mock web development starts as user 1, matching seedUsers['1'].
  await setTokens(
    Tokens(
      accessToken: mock_router.mockAccessTokenForUser(1),
      accessExpire: 0,
      refreshToken: '',
      refreshExpire: 0,
      refreshAfter: 0,
    ),
  );

  debugPrint('========================================');
  debugPrint('  Mock 模式已启动（默认登录：小白鸽）');
  debugPrint('  所有 API 请求将返回 Mock 数据');
  debugPrint('========================================');
  runApp(const ProviderScope(child: XiaobaiheApp()));
}
