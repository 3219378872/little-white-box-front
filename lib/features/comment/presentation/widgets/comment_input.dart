import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

class CommentInput extends StatefulWidget {
  final String? replyTo;
  final Future<void> Function(String) onSubmit;

  const CommentInput({super.key, this.replyTo, required this.onSubmit});

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(text);
      if (mounted) _controller.clear();
    } catch (_) {
      // 页面已提示；保留输入供重试。
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: FTextField(
                control: FTextFieldControl.managed(controller: _controller),
                hint: widget.replyTo != null
                    ? '回复 ${widget.replyTo}'
                    : '写评论...',
                textInputAction: TextInputAction.send,
                onSubmit: (_) => _submit(),
              ),
            ),
            const SizedBox(width: 8),
            FButton.icon(
              onPress: _submitting ? null : _submit,
              semanticsLabel: '发送评论',
              child: const Icon(FLucideIcons.send, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}
