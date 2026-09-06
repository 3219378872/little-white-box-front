import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

class CommentInput extends StatefulWidget {
  final String? replyTo;
  final Future<void> Function(String) onSubmit;
  final Widget? actions;

  const CommentInput({
    super.key,
    this.replyTo,
    required this.onSubmit,
    this.actions,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void didUpdateWidget(covariant CommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyTo != null && widget.replyTo != oldWidget.replyTo) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(text);
      if (mounted) {
        _controller.clear();
        _focusNode.unfocus();
      }
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                label: '评论内容',
                child: FTextField(
                  control: FTextFieldControl.managed(controller: _controller),
                  focusNode: _focusNode,
                  hint: widget.replyTo != null
                      ? '回复 ${widget.replyTo}'
                      : '写评论...',
                  textInputAction: TextInputAction.send,
                  onSubmit: (_) => _submit(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            if (widget.actions != null &&
                !_focusNode.hasFocus &&
                _controller.text.isEmpty)
              widget.actions!
            else
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
