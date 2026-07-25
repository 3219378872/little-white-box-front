import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// 模拟 app.dart 中的全局 FTheme 包裹，供依赖 Forui 组件的 widget 测试使用。
///
/// 用法：MaterialApp(builder: foruiTestBuilder, home: ...)
Widget foruiTestBuilder(BuildContext context, Widget? child) {
  return FTheme(
    data: FTheme.neutral.light.touch,
    child: FToaster(child: FTooltipGroup(child: child!)),
  );
}
