import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 带 tooltip 与读屏标签的 44×44 图标按钮，[selected] 时以次要底色表示激活态；
/// 用于页头与卡片上的图标操作。
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
