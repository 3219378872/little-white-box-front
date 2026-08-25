import 'dart:async';

import 'package:visibility_detector/visibility_detector.dart';

/// Flutter 自动为每个测试文件调用；集中处理跨用例的全局测试环境。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // VisibilityDetector 回调默认 500ms 节流，会在 widget 测试结束时留下
  // pending Timer；归零让回调随 pump 即时触发。
  VisibilityDetectorController.instance.updateInterval = Duration.zero;
  return testMain();
}
