import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/theme/app_theme.dart';

/// 模拟 app.dart 中的全局 FTheme 包裹，供依赖 Forui 组件的 widget 测试使用。
///
/// 用法：MaterialApp(builder: foruiTestBuilder, home: ...)
Widget foruiTestBuilder(BuildContext context, Widget? child) {
  return FTheme(
    data: Theme.brightnessOf(context) == Brightness.dark
        ? AppTheme.foruiDark
        : AppTheme.foruiLight,
    child: FToaster(child: FTooltipGroup(child: child!)),
  );
}
