import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart';

/// 帖子详情底部的评论输入栏；带回复目标时提示「回复 xxx」并自动聚焦。
///
/// 输入框空闲且未聚焦时用 [actions]（如点赞收藏）占据发送按钮的位置。
class CommentInput extends StatefulWidget {
  /// 当前回复对象的用户名；为空表示直接评论帖子。
  final String? replyTo;

  /// 提交去空白后的内容；抛错表示失败，输入栏会保留草稿。
  final Future<void> Function(String) onSubmit;
  final Widget? actions;

  /// Optional external focus node so the page can open the composer, e.g.
  /// from an empty comment list.
  final FocusNode? focusNode;

  const CommentInput({
    super.key,
    this.replyTo,
    required this.onSubmit,
    this.actions,
    this.focusNode,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

// 管理输入草稿、焦点与提交中状态。
class _CommentInputState extends State<CommentInput> {
  final _controller = TextEditingController();
  // 外部未提供焦点节点时才自建并负责释放。
  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  // 焦点或文本变化时重建，以切换操作区与发送按钮。
  void _refresh() => setState(() {});

  @override
  void didUpdateWidget(covariant CommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 回复目标变化时自动聚焦，方便直接输入。
    if (widget.replyTo != null && widget.replyTo != oldWidget.replyTo) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_refresh);
    _controller.dispose();
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  // 提交评论：防止重复提交；成功且期间未改动草稿时才清空输入并收起键盘。
  Future<void> _submit() async {
    final draft = _controller.text;
    final text = draft.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onSubmit(text);
      if (mounted && _controller.text == draft) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 评论输入框；键盘发送键同样触发提交。
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
            // 空闲时展示外部操作区，开始输入或聚焦后换成发送按钮。
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
