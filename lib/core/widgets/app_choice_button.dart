import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 单选组中的一个选项按钮：选中时为次要样式并带勾，未选中为描边样式。
///
/// 广告编辑与资质表单用它在 `Wrap` 中排列市场、行业等枚举选项。
class AppChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPress;

  const AppChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return FButton(
      size: FButtonSizeVariant.sm,
      mainAxisSize: MainAxisSize.min,
      variant: selected ? FButtonVariant.secondary : FButtonVariant.outline,
      prefix: selected ? const Icon(FLucideIcons.check) : null,
      onPress: onPress,
      child: Text(label),
    );
  }
}
