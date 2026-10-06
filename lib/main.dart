import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/error/global_error_handlers.dart';
import 'core/state/app_provider_scope.dart';

/// 真实网关入口：在受保护的 zone 中启动，并把框架、平台与 zone 三类未捕获异常
/// 统一交给全局错误处理。
void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = handlePlatformError;
    runApp(const AppProviderScope(child: XiaobaiheApp()));
  }, handleZoneError);
}
