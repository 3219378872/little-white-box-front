import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 整页或整块加载失败时的居中错误态；提供 [onRetry] 时显示「重试」按钮。
class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FLucideIcons.circleAlert, size: 48, color: theme.colors.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.typography.body.lg,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FButton(
                variant: FButtonVariant.secondary,
                onPress: onRetry!,
                child: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 列表或页面无数据时的居中空态。
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyView({
    super.key,
    this.message = '暂无内容',
    this.icon = FLucideIcons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: theme.colors.mutedForeground),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.typography.body.lg.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
