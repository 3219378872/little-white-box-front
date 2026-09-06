import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class AppIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPress;
  final bool selected;
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPress,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) => FTooltip(
    tipBuilder: (_, _) => Text(label),
    child: SizedBox(
      width: 44,
      height: 44,
      child: FButton.icon(
        variant: selected ? FButtonVariant.secondary : FButtonVariant.ghost,
        onPress: onPress,
        child: Icon(icon, size: 23, semanticLabel: label),
      ),
    ),
  );
}
