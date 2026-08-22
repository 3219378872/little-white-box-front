import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../application/assistant_notifier.dart';
import '../data/assistant_models.dart';

final RegExp _citationMarkerPattern = RegExp(r'\[[A-Za-z][A-Za-z0-9_-]*:\d+\]');
final RegExp _fullWidthMarkerPattern = RegExp('［post:[^］\\n]*］');
final RegExp _evidenceSourceLinePattern = RegExp(
  r'^\s*SOURCE\b[^\n]*$',
  multiLine: true,
);
final RegExp _evidenceJsonLinePattern = RegExp(
  r'^\s*COMMUNITY_CONTENT_JSON=.*$',
  multiLine: true,
);
final RegExp _evidenceHeaderLinePattern = RegExp(
  r'^\s*Community sources\b[^\n]*$',
  multiLine: true,
);
final RegExp _repeatedSpacePattern = RegExp(r' {2,}');
final RegExp _repeatedBlankLinePattern = RegExp(r'\n{3,}');

String stripCitationMarkers(String text) {
  final withoutEvidenceBlocks = text
      .replaceAll(_evidenceJsonLinePattern, '')
      .replaceAll(_evidenceSourceLinePattern, '')
      .replaceAll(_evidenceHeaderLinePattern, '')
      .replaceAll(_fullWidthMarkerPattern, '');
  final cleaned = withoutEvidenceBlocks
      .split('\n')
      .map(
        (line) => line
            .replaceAll(_citationMarkerPattern, '')
            .replaceAll(_repeatedSpacePattern, ' ')
            .trim(),
      )
      .join('\n');
  return cleaned.replaceAll(_repeatedBlankLinePattern, '\n\n').trim();
}

class AssistantPage extends ConsumerStatefulWidget {
  final ValueChanged<AssistantSourceReference>? onOpenSource;

  const AssistantPage({super.key, this.onOpenSource});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final accepted = ref
        .read(assistantNotifierProvider.notifier)
        .send(_controller.text);
    if (accepted) _controller.clear();
  }

  void _openSource(AssistantSourceReference source) {
    final callback = widget.onOpenSource;
    if (callback != null) {
      callback(source);
      return;
    }
    final id = Uri.encodeComponent(source.sourceId);
    if (source.isVerifiedPost) {
      context.push('/post/$id');
    }
  }

  bool _canOpen(AssistantSourceReference source) {
    return widget.onOpenSource != null || source.isVerifiedPost;
  }

  void _scheduleScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assistantNotifierProvider);
    ref.listen<AssistantState>(assistantNotifierProvider, (_, next) {
      if (next.messages.isNotEmpty) _scheduleScroll();
    });

    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('Assistant'),
        suffixes: state.messages.isEmpty
            ? const []
            : [
                FHeaderAction(
                  icon: const Icon(FLucideIcons.trash2),
                  semanticsLabel: '清空对话',
                  onPress: ref.read(assistantNotifierProvider.notifier).clear,
                ),
              ],
      ),
      child: Column(
        children: [
          Expanded(
            child: state.messages.isEmpty
                ? const EmptyView(
                    message: '开始新的对话',
                    icon: FLucideIcons.sparkles,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
                    itemCount: state.messages.length,
                    itemBuilder: (context, index) => _AssistantMessageBubble(
                      message: state.messages[index],
                      canOpenSource: _canOpen,
                      onOpenSource: _openSource,
                    ),
                  ),
          ),
          if (state.connectionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: FAlert(
                variant: FAlertVariant.destructive,
                title: Text(state.connectionError!),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: FTextField.multiline(
                      control: FTextFieldControl.managed(
                        controller: _controller,
                      ),
                      label: const Text('消息'),
                      hint: '输入消息',
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    key: const Key('assistant-send-or-stop'),
                    variant: state.isStreaming
                        ? FButtonVariant.secondary
                        : FButtonVariant.primary,
                    onPress: state.isStreaming
                        ? ref.read(assistantNotifierProvider.notifier).cancel
                        : _send,
                    child: Icon(
                      state.isStreaming
                          ? FLucideIcons.square
                          : FLucideIcons.send,
                      semanticLabel: state.isStreaming ? '停止生成' : '发送',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessageBubble extends StatelessWidget {
  final AssistantMessage message;
  final bool Function(AssistantSourceReference) canOpenSource;
  final ValueChanged<AssistantSourceReference> onOpenSource;

  const _AssistantMessageBubble({
    required this.message,
    required this.canOpenSource,
    required this.onOpenSource,
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
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: own ? theme.colors.primary : theme.colors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (bodyText.isNotEmpty)
                    own
                        ? Text(
                            bodyText,
                            style: theme.typography.body.md.copyWith(
                              color: foreground,
                            ),
                          )
                        : GptMarkdown(
                            bodyText,
                            style: theme.typography.body.md.copyWith(
                              color: foreground,
                            ),
                          ),
                  if (message.isStreaming) ...[
                    if (bodyText.isNotEmpty) const SizedBox(height: 8),
                    const FCircularProgress(size: .sm),
                  ],
                  if (message.sources.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final source in message.sources)
                          if (canOpenSource(source))
                            FButton(
                              variant: FButtonVariant.ghost,
                              onPress: () => onOpenSource(source),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    FLucideIcons.externalLink,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      source.title,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${source.sourceType}:${source.sourceId}',
                                    style: theme.typography.body.xs.copyWith(
                                      color: theme.colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            FBadge(
                              variant: FBadgeVariant.outline,
                              child: Text(
                                source.title.isEmpty
                                    ? '${source.sourceType}:${source.sourceId}'
                                    : source.title,
                              ),
                            ),
                      ],
                    ),
                  ],
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
