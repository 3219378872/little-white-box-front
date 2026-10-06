part of 'assistant_page.dart';

// Icon per agent tool; unknown tools fall back to a wrench.
IconData _toolIcon(String tool) {
  return switch (tool) {
    'search_posts' => FLucideIcons.fileSearch2,
    'web_search' => FLucideIcons.globe,
    'create_post' => FLucideIcons.penLine,
    'update_post' => FLucideIcons.filePen,
    'delete_post' => FLucideIcons.trash2,
    _ => FLucideIcons.wrench,
  };
}

// Confirm button for a tool awaiting approval: deletions keep the explicit,
// destructive wording; any other tool gets a neutral confirm.
(String, FButtonVariant) _toolConfirmAction(String tool) {
  return switch (tool) {
    'delete_post' => ('确认删除', FButtonVariant.destructive),
    _ => ('确认', FButtonVariant.primary),
  };
}

// Status text beside a tool step that is not running.
String _toolStatusLabel(AssistantToolStatus status) {
  return switch (status) {
    AssistantToolStatus.running => '执行中…',
    AssistantToolStatus.awaitingConfirmation => '等待确认',
    AssistantToolStatus.confirming => '提交中…',
    AssistantToolStatus.completed => '完成',
    AssistantToolStatus.confirmed => '已确认',
    AssistantToolStatus.declined => '已拒绝',
    AssistantToolStatus.expired => '已超时取消',
    AssistantToolStatus.failed => '失败',
  };
}

// One conversation row: user bubbles on the right, assistant replies as
// unboxed markdown on the left, system notices on a muted background.
class _AssistantMessageBubble extends StatelessWidget {
  final AnswerQuestion? onAnswerQuestion;
  final AssistantMessage message;
  final bool isStreaming;
  final VoidCallback? onRevealed;
  final bool Function(AssistantSourceCard) canOpenSource;
  final ValueChanged<AssistantSourceCard> onOpenSource;
  final void Function(String callId, bool approved)? onConfirm;
  final ValueChanged<AssistantSourceCard>? onDislikeCard;
  final ValueChanged<Object>? onUndo;

  const _AssistantMessageBubble({
    this.onAnswerQuestion,
    super.key,
    required this.message,
    required this.isStreaming,
    this.onRevealed,
    required this.canOpenSource,
    required this.onOpenSource,
    this.onConfirm,
    this.onDislikeCard,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final own = message.role == AssistantMessageRole.user;
    final bodyText = own ? message.text : stripCitationMarkers(message.text);
    final foreground = own
        ? theme.colors.primaryForeground
        : theme.colors.foreground;
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: own ? MediaQuery.sizeOf(context).width * 0.82 : 760,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: own
                  ? theme.colors.primary
                  : message.role == AssistantMessageRole.system
                  ? theme.colors.muted
                  : const Color(0x00000000),
              // Chat bubble: rounded with a tighter corner toward the sender.
              borderRadius: own
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    )
                  : AppTheme.controlRadius,
            ),
            child: Padding(
              padding: own
                  ? const EdgeInsets.all(12)
                  : const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // User attachments above the text.
                  if (own && message.attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final image in message.attachments)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              image.thumbnailUrl.isNotEmpty
                                  ? image.thumbnailUrl
                                  : image.url,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                    if (bodyText.isNotEmpty) const SizedBox(height: 8),
                  ],
                  // Tool steps; ask_questions is shown as the question card instead.
                  if (message.toolSteps.isNotEmpty) ...[
                    for (final step in message.toolSteps.where(
                      (step) => step.tool != 'ask_questions',
                    ))
                      _ToolStepEntry(step: step, onConfirm: onConfirm),
                    if (bodyText.isNotEmpty || isStreaming)
                      const SizedBox(height: 8),
                  ],
                  // Body, by priority: question card, structured research answer, plain user
                  // text, streaming markdown, final markdown.
                  if (message.questionRequest != null &&
                      onAnswerQuestion != null)
                    AssistantQuestionCard(
                      question: message.questionRequest!,
                      onAnswer: onAnswerQuestion!,
                    )
                  else if (message.answerPresentation != null)
                    AssistantResearchAnswer(
                      answer: message.answerPresentation!,
                      onDislike: onDislikeCard,
                    )
                  else if (own && bodyText.isNotEmpty)
                    Text(
                      bodyText,
                      style: theme.typography.body.md.copyWith(
                        color: foreground,
                      ),
                    )
                  else if (!own && isStreaming)
                    StreamingMarkdownBody(
                      key: ValueKey(message.id),
                      committedText: bodyText,
                      isStreaming: true,
                      style: theme.typography.body.md.copyWith(
                        color: foreground,
                      ),
                      foreground: foreground,
                      onRevealed: onRevealed,
                    )
                  else if (!own && bodyText.isNotEmpty)
                    GptMarkdown(
                      bodyText,
                      style: theme.typography.body.md.copyWith(
                        color: foreground,
                      ),
                    ),
                  // Progress indicator while a plain reply is still streaming.
                  if (isStreaming &&
                      message.questionRequest == null &&
                      message.answerPresentation == null) ...[
                    if (bodyText.isNotEmpty) const SizedBox(height: 8),
                    const FCircularProgress(size: .sm),
                  ],
                  // Source cards pushed during streaming.
                  AssistantSourceCards(
                    message: message,
                    canOpen: canOpenSource,
                    onOpen: onOpenSource,
                    onDislike: onDislikeCard ?? (_) {},
                  ),
                  // Undo entry on memory change notices.
                  if (message.isMemoryChanged &&
                      jsonInt64IsPositive(message.changeId)) ...[
                    const SizedBox(height: 8),
                    FButton(
                      variant: .ghost,
                      size: .sm,
                      onPress:
                          onUndo == null ||
                              message.memoryUndoing ||
                              message.memoryUndone
                          ? null
                          : () => onUndo!(message.changeId),
                      child: Text(
                        message.memoryUndone
                            ? '记忆变更已撤销'
                            : message.memoryUndoing
                            ? '正在撤销…'
                            : '撤销这次记忆变更',
                      ),
                    ),
                  ],
                  // Footnote for stopped or degraded replies.
                  if (message.degraded || message.isCanceled) ...[
                    const SizedBox(height: 8),
                    Text(
                      message.isCanceled ? '已停止' : '降级响应',
                      style: theme.typography.body.xs.copyWith(
                        color: foreground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// One tool step row; a step awaiting confirmation adds cancel and a
// tool-specific confirm button, and delete_post gets a warning icon.
class _ToolStepEntry extends StatelessWidget {
  final AssistantToolStep step;
  final void Function(String callId, bool approved)? onConfirm;

  const _ToolStepEntry({required this.step, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final awaiting = step.status == AssistantToolStatus.awaitingConfirmation;
    final (confirmLabel, confirmVariant) = _toolConfirmAction(step.tool);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.muted.withValues(alpha: .35),
          borderRadius: theme.style.borderRadius.md,
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    step.tool == 'delete_post'
                        ? FLucideIcons.triangleAlert
                        : _toolIcon(step.tool),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      step.summary.isEmpty ? step.tool : step.summary,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.sm,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (step.status == AssistantToolStatus.running)
                    const FCircularProgress(size: .xs)
                  else
                    Text(
                      _toolStatusLabel(step.status),
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                ],
              ),
              if (awaiting) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FButton(
                      variant: .outline,
                      size: .sm,
                      onPress: onConfirm == null
                          ? null
                          : () => onConfirm!(step.callId, false),
                      child: const Text('取消'),
                    ),
                    const SizedBox(width: 8),
                    FButton(
                      variant: confirmVariant,
                      size: .sm,
                      onPress: onConfirm == null
                          ? null
                          : () => onConfirm!(step.callId, true),
                      child: Text(confirmLabel),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
