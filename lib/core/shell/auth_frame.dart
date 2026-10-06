import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../widgets/content_constraint.dart';

/// Auth pages sit outside `MainShell`; paint the theme background across the
/// whole viewport so wide dark layouts do not show the default white canvas
/// beside the 440px column.
class AuthFrame extends StatelessWidget {
  final Widget child;

  const AuthFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) => ColoredBox(
    key: const Key('auth-frame'),
    color: context.theme.colors.background,
    child: ContentConstraint(maxWidth: 440, child: child),
  );
}
