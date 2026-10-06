import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

/// 本人主页的快捷入口：编辑资料与助手记忆，两枚按钮等宽并排。
class ProfileShortcuts extends StatelessWidget {
  const ProfileShortcuts({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _shortcut(
          context,
          FLucideIcons.userRoundPen,
          '编辑资料',
          AppRoutes.profileEdit,
        ),
        const SizedBox(width: 8),
        _shortcut(
          context,
          FLucideIcons.notebook,
          '记忆',
          AppRoutes.assistantMemory,
        ),
      ],
    );
  }

  // 图标在上、文字在下的次级按钮，点击 push 到对应路由。
  Widget _shortcut(
    BuildContext context,
    IconData icon,
    String label,
    String route,
  ) => Expanded(
    child: FButton(
      variant: FButtonVariant.secondary,
      onPress: () => context.push(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
