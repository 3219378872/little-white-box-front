import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide InputBorder, OutlineInputBorder;
import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart'
    show InputBorder, OutlineInputBorder;

/// Shared design tokens. Pages read spacing, radii and brand colors from here
/// instead of hard-coding values, so light/dark and touch/desktop stay aligned.
class AppTheme {
  // Spacing scale on a 4/8 grid.
  static const space1 = 4.0;
  static const space2 = 8.0;
  static const space3 = 12.0;
  static const space4 = 16.0;
  static const space6 = 24.0;

  static const pageInset = space4;
  static const contentGap = space2;

  // Radius scale: tags 4, images and controls 8, cards and sheets 12.
  static const tagRadius = BorderRadius.all(Radius.circular(4));
  static const imageRadius = BorderRadius.all(Radius.circular(8));
  static const controlRadius = BorderRadius.all(Radius.circular(8));
  static const cardRadius = BorderRadius.all(Radius.circular(12));

  // Desktop layout widths.
  static const feedColumnWidth = 680.0;
  static const sideRailWidth = 288.0;
  static const sidebarWidth = 240.0;
  static const sidebarCollapsedWidth = 72.0;

  /// Brand accent: selected tabs, primary buttons, links and active states.
  static const accentLight = Color(0xFF2563EB);
  static const accentDark = Color(0xFF60A5FA);
  static const link = accentLight;
  static const assistantCard = FCardStyleDelta.delta(
    decoration: DecorationDelta.boxDelta(borderRadius: cardRadius),
  );
  static const _seedColor = Color(0xFF14191E);

  /// Low-emphasis tint of the accent for selected chips and highlights.
  static Color accentSoft(FColors colors) =>
      colors.primary.withValues(alpha: .12);

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
      primary: dark ? accentDark : accentLight,
      primaryForeground: dark ? const Color(0xFF0B1220) : Colors.white,
      secondary: dark ? const Color(0xFF222426) : const Color(0xFFF3F4F5),
      secondaryForeground: dark
          ? const Color(0xFFB9BDC1)
          : const Color(0xFF64696E),
      muted: dark ? const Color(0xFF1E1F21) : const Color(0xFFF7F8F9),
      // Light muted text is 4.9:1 on white so meta text meets WCAG AA.
      mutedForeground: dark ? const Color(0xFF9B9FA2) : const Color(0xFF6B7075),
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
            xs2: tagRadius,
            xs: tagRadius,
            sm: controlRadius,
            md: controlRadius,
            lg: cardRadius,
            xl: cardRadius,
            xl2: cardRadius,
            xl3: cardRadius,
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
          borderRadius: controlRadius,
          borderSide: BorderSide.none,
        ),
        variants: {
          [FTextFieldVariant.focused]: OutlineInputBorder(
            borderRadius: controlRadius,
            borderSide: BorderSide(color: colors.primary),
          ),
          [FTextFieldVariant.error]: OutlineInputBorder(
            borderRadius: controlRadius,
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
        borderRadius: tagRadius,
        border: outline ? Border.all(color: colors.border) : null,
      ),
      labelTextStyle: body.xs.copyWith(color: foreground),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    );
    final sidebar =
        FSidebarStyle.inherit(
          colors: colors,
          typography: typography,
          icons: variant.icons,
          style: style,
          touch: touch,
        ).copyWith(
          constraints: const BoxConstraints.tightFor(width: sidebarWidth),
          headerPadding: const EdgeInsetsGeometryDelta.value(
            EdgeInsets.fromLTRB(0, 12, 0, 4),
          ),
          groupStyle: FSidebarGroupStyleDelta.delta(
            itemStyle: FSidebarItemStyleDelta.delta(
              padding: const EdgeInsetsGeometryDelta.value(
                EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              ),
              iconSpacing: 12,
              borderRadius: controlRadius,
              textStyle: FVariants.from(
                body.sm.copyWith(
                  color: colors.foreground,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                variants: {
                  [FTappableVariant.selected]: TextStyleDelta.delta(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                },
              ),
              iconStyle: FVariants.from(
                IconThemeData(color: colors.foreground, size: 20),
                variants: {
                  [FTappableVariant.selected]: IconThemeDataDelta.delta(
                    color: colors.primary,
                  ),
                },
              ),
              backgroundColor: FVariants(
                colors.background,
                variants: {
                  [FTappableVariant.hovered, FTappableVariant.pressed]:
                      colors.secondary,
                  [FTappableVariant.selected]: accentSoft(colors),
                },
              ),
            ),
          ),
        );
    return FThemeData(
      colors: colors,
      typography: typography,
      style: style,
      sidebarStyle: sidebar,
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
                  bottom: BorderSide(color: colors.primary, width: 2),
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
              BoxDecoration(
                color: colors.background,
                border: Border(top: BorderSide(color: colors.border)),
              ),
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
