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
    final touch =
        const <TargetPlatform>{.android, .iOS, .fuchsia}.contains(
          defaultTargetPlatform,
        );
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
    final isLight = colorScheme.brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLowest,
      textTheme: TextTheme(
        // 帖子标题：黑、粗、紧凑
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
          height: 1.35,
        ),
        // 正文：灰一度、行高放宽，与标题拉开层次
        bodyMedium: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant,
          height: 1.5,
        ),
        // 标签、统计等辅助信息
        labelSmall: TextStyle(
          fontSize: 12,
          color: colorScheme.outline,
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: colorScheme.surfaceContainerLowest,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: colorScheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        // 亮色下卡片纯白，与浅蓝灰背景拉开明暗差
        color: isLight ? Colors.white : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        // 淡蓝底 + 主色文字，标签从灰 pill 变成品牌色点缀
        backgroundColor:
            colorScheme.primaryContainer.withValues(alpha: 0.45),
        labelStyle: TextStyle(fontSize: 12, color: colorScheme.primary),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 0.5,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }
}
