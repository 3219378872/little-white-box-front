import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AppTheme {
  static const _seedColor = Color(0xFF3B6CA8);

  /// Forui 亮色主题：neutral 基础 + 品牌蓝 primary
  static final FThemeData foruiLight = _foruiTheme(FTheme.neutral.light);

  /// Forui 暗色主题：neutral 基础 + 品牌蓝 primary
  static final FThemeData foruiDark = _foruiTheme(FTheme.neutral.dark);

  static FThemeData _foruiTheme(FPlatformThemeData base) {
    final touch = const <TargetPlatform>{
      .android,
      .iOS,
      .fuchsia,
    }.contains(defaultTargetPlatform);
    final variant = touch ? base.touch : base.desktop;
    return FThemeData(
      colors: variant.colors.copyWith(
        primary: _seedColor,
        primaryForeground: Colors.white,
      ),
      typography: variant.typography,
      style: variant.style,
      touch: touch,
    );
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.light,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: Brightness.dark,
    );
    return _buildTheme(colorScheme);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
    );
  }
}
