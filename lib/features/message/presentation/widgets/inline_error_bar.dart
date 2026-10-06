import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 线程页输入区上方的单行错误横幅（发送失败、标记已读失败），右侧带一个重试按钮。
class InlineErrorBar extends StatelessWidget {
  /// 横幅标题，直接展示给用户的错误文案。
  final String message;

  /// 重试按钮的读屏标签，测试也按它定位按钮。
  final String retryLabel;

  /// 为 null 时按钮禁用（重试进行中）。
  final VoidCallback? onRetry;

  /// 为 true 时按钮内显示进度圈而非重试图标。
  final bool retrying;

  const InlineErrorBar({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
    this.retrying = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: FAlert(
              variant: FAlertVariant.destructive,
              title: Text(message),
            ),
          ),
          const SizedBox(width: 8),
          FButton.icon(
            onPress: onRetry,
            child: retrying
                ? const FCircularProgress(size: .sm)
                : Icon(FLucideIcons.refreshCw, semanticLabel: retryLabel),
          ),
        ],
      ),
    );
  }
}
