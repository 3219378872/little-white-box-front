import 'package:flutter/material.dart' hide InputBorder, OutlineInputBorder;
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart' show OutlineInputBorder;
import 'package:xiaobaihe_app/core/theme/app_theme.dart';

// 主题快照：固定亮/暗两套 Forui 主题中各组件的关键颜色与尺寸，
// 保证拆分或整理 _foruiTheme 时产出的主题值不发生漂移。
void main() {
  // 每套主题的期望色板；其余断言都从这里推导，避免两套主题各写一遍。
  final cases = {
    'light': (
      theme: AppTheme.foruiLight,
      primary: AppTheme.accentLight,
      primaryForeground: const Color(0xFFFFFFFF),
      secondary: const Color(0xFFF3F4F5),
      secondaryForeground: const Color(0xFF64696E),
      muted: const Color(0xFFF7F8F9),
      mutedForeground: const Color(0xFF6B7075),
      border: const Color(0xFFF0F1F2),
    ),
    'dark': (
      theme: AppTheme.foruiDark,
      primary: AppTheme.accentDark,
      primaryForeground: const Color(0xFF0B1220),
      secondary: const Color(0xFF222426),
      secondaryForeground: const Color(0xFFB9BDC1),
      muted: const Color(0xFF1E1F21),
      mutedForeground: const Color(0xFF9B9FA2),
      border: const Color(0xFF27292C),
    ),
  };

  for (final MapEntry(key: name, value: c) in cases.entries) {
    group('$name theme snapshot', () {
      final theme = c.theme;
      final colors = theme.colors;

      test('palette overrides', () {
        expect(colors.primary, c.primary);
        expect(colors.primaryForeground, c.primaryForeground);
        expect(colors.secondary, c.secondary);
        expect(colors.secondaryForeground, c.secondaryForeground);
        expect(colors.muted, c.muted);
        expect(colors.mutedForeground, c.mutedForeground);
        expect(colors.border, c.border);
      });

      test('typography scale and radii', () {
        final body = theme.typography.body;
        final display = theme.typography.display;
        expect(
          [
            body.xs3,
            body.xs2,
            body.xs,
            body.sm,
            body.md,
            body.lg,
          ].map((s) => s.fontSize),
          [10, 11, 12, 14, 16, 18],
        );
        expect(body.sm.height, 1.45);
        expect(body.sm.color, colors.foreground);
        expect(display.sm.fontSize, 20);
        expect(display.sm.fontWeight, FontWeight.w600);
        expect(display.lg.fontWeight, FontWeight.w700);
        expect(theme.style.borderRadius.xs, AppTheme.tagRadius);
        expect(theme.style.borderRadius.md, AppTheme.controlRadius);
        expect(theme.style.borderRadius.xl3, AppTheme.cardRadius);
      });

      test('sidebar items', () {
        final sidebar = theme.sidebarStyle;
        expect(sidebar.constraints.maxWidth, AppTheme.sidebarWidth);
        final item = sidebar.groupStyle.itemStyle;
        expect(item.iconSpacing, 12);
        expect(item.borderRadius, AppTheme.controlRadius);
        expect(item.backgroundColor.base, colors.background);
        expect(
          item.backgroundColor.resolve({FTappableVariant.hovered}),
          colors.secondary,
        );
        expect(
          item.backgroundColor.resolve({FTappableVariant.selected}),
          AppTheme.accentSoft(colors),
        );
        final selectedText = item.textStyle.resolve({
          FTappableVariant.selected,
        });
        expect(selectedText.color, colors.primary);
        expect(selectedText.fontWeight, FontWeight.w600);
        expect(item.iconStyle.base.size, 20);
      });

      test('badges', () {
        final primary = theme.badgeStyles.base;
        expect((primary.decoration as BoxDecoration).color, colors.primary);
        expect(primary.labelTextStyle.color, colors.primaryForeground);
        expect(
          primary.padding,
          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        );
        final secondary = theme.badgeStyles.resolve({FBadgeVariant.secondary});
        expect((secondary.decoration as BoxDecoration).color, colors.secondary);
        final outline = theme.badgeStyles.resolve({FBadgeVariant.outline});
        expect(
          (outline.decoration as BoxDecoration).border,
          Border.all(color: colors.border),
        );
      });

      test('filled text fields', () {
        for (final size in [
          FTextFieldSizeVariant.sm,
          FTextFieldSizeVariant.md,
          FTextFieldSizeVariant.lg,
        ]) {
          final field = theme.textFieldStyles.resolve({size});
          expect(field.color.base, colors.muted);
          expect(field.contentTextStyle.base.fontSize, 14);
          final focused = field.border.resolve({
            FTextFieldVariant.focused,
          }) as OutlineInputBorder;
          expect(focused.borderSide.color, colors.primary);
          expect(focused.borderRadius, AppTheme.controlRadius);
        }
      });

      test('alerts, tabs and bottom navigation', () {
        expect(theme.alertStyles.primary.titleTextStyle.fontSize, 14);
        final tabs = theme.tabsStyle;
        expect(tabs.minHeight, 46);
        expect(tabs.spacing, 0);
        expect(
          tabs.labelTextStyle.resolve({FTabVariant.selected}).color,
          colors.foreground,
        );
        final bar = theme.bottomNavigationBarStyle;
        expect((bar.decoration as BoxDecoration).color, colors.background);
        expect(
          bar.padding,
          const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        );
      });
    });
  }
}
