import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// Rebuilds [child] from scratch each time the system fonts change.
///
/// `RenderParagraph` measures its intrinsic size with a separate text painter
/// that `systemFontsDidChange` does not reset. A parent that sizes itself from
/// intrinsics, such as the `IntrinsicWidth` inside [FBadge], therefore keeps
/// the width measured before a web fallback font (CJK glyphs) finished
/// loading, and later glyphs are clipped. A new key replaces those render
/// objects so they measure again with the loaded font.
class SystemFontsRefresh extends StatefulWidget {
  final Widget child;

  const SystemFontsRefresh({super.key, required this.child});

  @override
  State<SystemFontsRefresh> createState() => _SystemFontsRefreshState();
}

class _SystemFontsRefreshState extends State<SystemFontsRefresh> {
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onSystemFontsChanged);
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onSystemFontsChanged);
    super.dispose();
  }

  void _onSystemFontsChanged() {
    if (mounted) setState(() => _generation++);
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: ValueKey(_generation), child: widget.child);
}

/// [FBadge] whose label is measured again once fallback fonts load.
class AppBadge extends StatelessWidget {
  final FBadgeVariant variant;
  final Widget child;

  const AppBadge({
    super.key,
    this.variant = FBadgeVariant.primary,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => SystemFontsRefresh(
    child: FBadge(variant: variant, child: child),
  );
}
