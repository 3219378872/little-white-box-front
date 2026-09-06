import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AppTheme {
  static const pageInset = 12.0;
  static const contentGap = 6.0;
  static const imageRadius = BorderRadius.all(Radius.circular(4));
  static const link = Color(0xFF23649A);
  static const assistantCard = FCardStyleDelta.delta(
    decoration: DecorationDelta.boxDelta(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
  );
  static const _seedColor = Color(0xFF14191E);

  static FTextFieldStyleDelta editorField(
    BuildContext context, {
    bool title = false,
  }) {
    final theme = context.theme;
    final text = title ? theme.typography.display.sm : theme.typography.body.md;
    return FTextFieldStyleDelta.delta(
      border: FVariants.all(InputBorder.none),
      color: FVariants.all(Colors.transparent),
      contentPadding: const EdgeInsetsGeometryDelta.value(
        EdgeInsets.symmetric(vertical: 12),
      ),
      contentTextStyle: FVariants.all(text),
      hintTextStyle: FVariants.all(
        text.copyWith(color: theme.colors.mutedForeground),
      ),
    );
  }

  /// Shared Android-reference tokens; business pages keep the same theme owner.
  static final FThemeData foruiLight = _foruiTheme(FTheme.neutral.light);

  static final FThemeData foruiDark = _foruiTheme(FTheme.neutral.dark);

  static FThemeData _foruiTheme(FPlatformThemeData base) {
    final touch = const <TargetPlatform>{
      .android,
      .iOS,
      .fuchsia,
    }.contains(defaultTargetPlatform);
    final variant = touch ? base.touch : base.desktop;
    final dark = variant.colors.brightness == Brightness.dark;
    final colors = variant.colors.copyWith(
      background: dark ? const Color(0xFF101112) : Colors.white,
      foreground: dark ? const Color(0xFFE1E2E3) : _seedColor,
      primary: dark ? const Color(0xFFE1E2E3) : _seedColor,
      primaryForeground: dark ? _seedColor : Colors.white,
      secondary: dark ? const Color(0xFF222426) : const Color(0xFFF3F4F5),
      secondaryForeground: dark
          ? const Color(0xFFB9BDC1)
          : const Color(0xFF64696E),
      muted: dark ? const Color(0xFF1E1F21) : const Color(0xFFF7F8F9),
      mutedForeground: dark ? const Color(0xFF9B9FA2) : const Color(0xFF8C9196),
      border: dark ? const Color(0xFF27292C) : const Color(0xFFF0F1F2),
    );
    TextStyle text(
      double size, {
      FontWeight weight = FontWeight.w400,
      double height = 1.45,
    }) => TextStyle(
      fontFamily: FTypeface.defaultFontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
      color: colors.foreground,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final body = FTypeface(
      xs3: text(10),
      xs2: text(11),
      xs: text(12),
      sm: text(14),
      md: text(16),
      lg: text(18),
      xl: text(20),
      xl2: text(24),
    );
    final typography = FTypography(
      body: body,
      display: body.copyWith(
        sm: text(20, weight: FontWeight.w600),
        md: text(22, weight: FontWeight.w600),
        lg: text(24, weight: FontWeight.w700),
        xl: text(20, weight: FontWeight.w600),
        xl2: text(24, weight: FontWeight.w700),
      ),
    );
    final style =
        FStyle.inherit(
          colors: colors,
          typography: typography,
          touch: touch,
        ).copyWith(
          borderRadius: const FBorderRadius(
            xs2: BorderRadius.all(Radius.circular(2)),
            xs: imageRadius,
            sm: imageRadius,
            md: BorderRadius.all(Radius.circular(6)),
            lg: BorderRadius.all(Radius.circular(8)),
            xl: BorderRadius.all(Radius.circular(8)),
            xl2: BorderRadius.all(Radius.circular(8)),
            xl3: BorderRadius.all(Radius.circular(8)),
          ),
          shadow: const [],
        );
    final fields = FTextFieldSizeStyles.inherit(
      colors: colors,
      typography: typography,
      style: style,
      touch: touch,
    );
    FTextFieldStyle filledField(FTextFieldStyle field) => field.copyWith(
      color: FVariants.all(colors.muted),
      contentTextStyle: FVariants.from(
        body.sm,
        variants: {
          [FTextFieldVariant.disabled]: TextStyleDelta.delta(
            color: colors.disable(colors.foreground),
          ),
        },
      ),
      border: FVariants(
        OutlineInputBorder(
          borderRadius: imageRadius,
          borderSide: BorderSide.none,
        ),
        variants: {
          [FTextFieldVariant.focused]: OutlineInputBorder(
            borderRadius: imageRadius,
            borderSide: BorderSide(color: colors.mutedForeground),
          ),
          [FTextFieldVariant.error]: OutlineInputBorder(
            borderRadius: imageRadius,
            borderSide: BorderSide(color: colors.destructive),
          ),
        },
      ),
    );
    FBadgeStyle badge(
      Color background,
      Color foreground, {
      bool outline = false,
    }) => FBadgeStyle(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(2),
        border: outline ? Border.all(color: colors.border) : null,
      ),
      labelTextStyle: body.xs.copyWith(color: foreground),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    );
    return FThemeData(
      colors: colors,
      typography: typography,
      style: style,
      badgeStyles: FVariants(
        badge(colors.primary, colors.primaryForeground),
        variants: {
          [FBadgeVariant.secondary]: badge(
            colors.secondary,
            colors.secondaryForeground,
          ),
          [FBadgeVariant.outline]: badge(
            colors.background,
            colors.foreground,
            outline: true,
          ),
          [FBadgeVariant.destructive]: badge(
            colors.destructive.withValues(alpha: .1),
            colors.destructive,
          ),
        },
      ),
      textFieldStyles: FVariants(
        filledField(fields.md),
        variants: {
          [FTextFieldSizeVariant.sm]: filledField(fields.sm),
          [FTextFieldSizeVariant.md]: filledField(fields.md),
          [FTextFieldSizeVariant.lg]: filledField(fields.lg),
        },
      ),
      tabsStyle:
          FTabsStyle.inherit(
            colors: colors,
            typography: typography,
            style: style,
          ).copyWith(
            decoration: const DecorationDelta.value(BoxDecoration()),
            padding: const EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
            minHeight: 46,
            spacing: 0,
            indicatorSize: FTabBarIndicatorSize.label,
            indicatorDecoration: DecorationDelta.value(
              BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.foreground, width: 2),
                ),
              ),
            ),
            labelTextStyle: FVariants.from(
              body.md.copyWith(color: colors.mutedForeground),
              variants: {
                [FTabVariant.selected]: TextStyleDelta.delta(
                  color: colors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              },
            ),
          ),
      bottomNavigationBarStyle:
          FBottomNavigationBarStyle.inherit(
            colors: colors,
            typography: typography,
            style: style,
          ).copyWith(
            decoration: DecorationDelta.value(
              BoxDecoration(color: colors.muted),
            ),
            padding: const EdgeInsetsGeometryDelta.value(
              EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            ),
          ),
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
      scaffoldBackgroundColor: colorScheme.brightness == Brightness.dark
          ? const Color(0xFF101112)
          : Colors.white,
    );
  }
}
