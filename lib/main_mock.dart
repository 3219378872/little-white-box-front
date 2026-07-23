import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'sdk/api/api.dart';
import 'mock/mock_http.dart';

/// Mock 模式入口
///
/// 使用方式：flutter run -d web-server -t lib/main_mock.dart
/// 所有 HTTP 请求将被拦截并返回内存中的 Mock 数据
void main() {
  setApiClient(MockHttpClient());
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('========================================');
  debugPrint('  Mock 模式已启动');
  debugPrint('  所有 API 请求将返回 Mock 数据');
  debugPrint('========================================');
  runApp(const ProviderScope(child: XiaobaiheApp()));
}
