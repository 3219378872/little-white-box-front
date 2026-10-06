import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 媒体上传或发送失败后保留的待发送项：展示错误，可重试（复用已上传结果）或取消。
class PendingMediaRow extends StatelessWidget {
  /// 媒体发送控制器给出的错误文案。
  final String error;

  /// 重试进行中时禁用重试按钮；取消始终可用。
  final bool busy;

  /// 重试上传或发送，已上传的媒体不会重传。
  final VoidCallback onRetry;

  /// 放弃这条待发送媒体。
  final VoidCallback onCancel;

  const PendingMediaRow({
    super.key,
    required this.error,
    required this.busy,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Expanded(child: Text(error)),
          FButton.icon(
            onPress: busy ? null : onRetry,
            child: const Icon(FLucideIcons.refreshCw, semanticLabel: '重试媒体发送'),
          ),
          FButton.icon(
            onPress: onCancel,
            child: const Icon(FLucideIcons.x, semanticLabel: '取消媒体发送'),
          ),
        ],
      ),
    );
  }
}
