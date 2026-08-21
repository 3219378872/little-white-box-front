import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/auth/session_tokens.dart';
import 'sdk/api/api.dart';
import 'mock/mock_http.dart';
import 'mock/mock_router.dart' as mock_router;
import 'sdk/vars/kv.dart';

/// Mock 模式入口
///
/// 使用方式：flutter run -d web-server -t lib/main_mock.dart
/// 所有 HTTP 请求将被拦截并返回内存中的 Mock 数据
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setApiClient(MockHttpClient());

  // Mock web development starts as user 1, matching seedUsers['1'].
  await setTokens(buildStoredTokens(
    accessToken: mock_router.mockAccessTokenForUser(1),
    refreshToken: mock_router.mockRefreshTokenForUser(1),
  ));

  debugPrint('========================================');
  debugPrint('  Mock 模式已启动（默认登录：小白鸽）');
  debugPrint('  所有 API 请求将返回 Mock 数据');
  debugPrint('========================================');
  runApp(const ProviderScope(child: XiaobaiheApp()));
}
