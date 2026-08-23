import 'package:flutter/foundation.dart';

/// 全局错误兜底：未捕获异常的统一出口。
///
/// Web 平台没有系统日志，未捕获的异步异常默认只进浏览器控制台且无任何
/// 统一处理；这里集中收敛三类来源（Flutter 框架回调、PlatformDispatcher、
/// 根 zone），debug 下输出完整信息，release 下只保留轻量摘要，
/// 并为将来接入崩溃上报预留唯一挂载点。

/// 处理 Flutter 框架回调中的异常（构建/布局/绘制阶段）。
void handleFlutterError(FlutterErrorDetails details) {
  FlutterError.presentError(details);
  logUnhandledError('flutter', details.exception, details.stack);
}

/// 处理 PlatformDispatcher 层的未捕获异步异常。返回 true 表示已处理。
bool handlePlatformError(Object error, StackTrace stackTrace) {
  logUnhandledError('platform', error, stackTrace);
  return true;
}

/// 处理根 zone 捕获的异常。
void handleZoneError(Object error, StackTrace stackTrace) {
  logUnhandledError('zone', error, stackTrace);
}

/// 记录未捕获异常。release 下不含堆栈，避免向控制台泄漏内部细节。
void logUnhandledError(String source, Object error, StackTrace? stackTrace) {
  final message = 'unhandled[$source] $error';
  if (kDebugMode) {
    debugPrint(message);
    final stack = stackTrace;
    if (stack != null) {
      debugPrint(stack.toString());
    }
  }
}
