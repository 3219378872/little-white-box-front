import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';

/// 带标题的卡片分区，供控制台与工作台等表单页复用。
class AppSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FCard(
      style: AppTheme.assistantCard,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppTheme.space3),
            child,
          ],
        ),
      ),
    );
  }
}

/// 标签与值并列的一行只读信息。
class AppInfoRow extends StatelessWidget {
  final String label;
  final Widget value;

  const AppInfoRow({super.key, required this.label, required this.value});

  AppInfoRow.text({super.key, required this.label, required String text})
    : value = Text(text);

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: DefaultTextStyle.merge(
              style: theme.typography.body.sm,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}
