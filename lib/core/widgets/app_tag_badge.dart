import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// A theme-aware tag badge that preserves the intrinsic width of CJK labels.
class AppTagBadge extends StatelessWidget {
  final String label;
  final VoidCallback? onRemove;

  const AppTagBadge({super.key, required this.label, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    const horizontalPadding = 6.0;
    final labelStyle = theme.typography.body.xs.copyWith(
      color: theme.colors.secondaryForeground,
      fontWeight: FontWeight.w500,
    );

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: theme.colors.secondary,
        shape: RoundedSuperellipseBorder(
          borderRadius: theme.style.borderRadius.xs2,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          horizontalPadding,
          3,
          onRemove == null ? horizontalPadding : 6,
          3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
            ),
            if (onRemove != null) ...[
              const SizedBox(width: 4),
              FTappable(
                onPress: onRemove,
                semanticsLabel: '移除标签 $label',
                child: Icon(
                  FLucideIcons.x,
                  size: 14,
                  color: theme.colors.secondaryForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
