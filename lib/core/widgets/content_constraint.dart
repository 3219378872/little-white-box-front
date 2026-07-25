import 'package:flutter/widgets.dart';

/// 宽屏下将页面内容限宽居中，避免移动端单列布局被拉满全宽。
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double horizontalPadding;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.horizontalPadding = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}
