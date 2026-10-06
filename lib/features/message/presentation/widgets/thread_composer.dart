import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 线程页底部的文本输入与发送按钮；输入内容由页面持有的 [controller] 管理，便于发送成功后清空。
class ThreadComposer extends StatelessWidget {
  /// 页面持有的输入控制器。
  final TextEditingController controller;

  /// 文本发送进行中，发送按钮显示进度圈。
  final bool sending;

  /// 为 null 时发送按钮禁用。
  final VoidCallback? onSend;

  const ThreadComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Semantics(
                label: '消息',
                child: FTextField.multiline(
                  control: FTextFieldControl.managed(controller: controller),
                  hint: '输入消息',
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 1000,
                ),
              ),
            ),
            const SizedBox(width: 8),
            FButton.icon(
              onPress: onSend,
              child: sending
                  ? const FCircularProgress(size: .sm)
                  : const Icon(FLucideIcons.send, semanticLabel: '发送'),
            ),
          ],
        ),
      ),
    );
  }
}
