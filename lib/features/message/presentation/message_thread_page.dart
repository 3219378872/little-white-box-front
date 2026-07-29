import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/message_notifiers.dart';
import '../data/message_models.dart';

class MessageThreadPage extends ConsumerStatefulWidget {
  final int conversationId;
  final int targetUserId;
  final String targetUserName;

  const MessageThreadPage({
    super.key,
    required this.conversationId,
    required this.targetUserId,
    this.targetUserName = '',
  });

  @override
  ConsumerState<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  MessageThreadKey _key(int currentUserId) => MessageThreadKey(
    conversationId: widget.conversationId,
    targetUserId: widget.targetUserId,
    currentUserId: currentUserId,
  );

  Future<void> _send(MessageThreadKey key) async {
    final sent = await ref
        .read(messageThreadProvider(key).notifier)
        .send(_controller.text);
    if (!mounted || !sent) return;
    _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _scrollToEnd() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final title = widget.targetUserName.isEmpty
        ? '用户 ${widget.targetUserId}'
        : widget.targetUserName;
    final currentUserId = auth.userId?.toInt() ?? 0;
    if (auth.isLoading || currentUserId <= 0) {
      return FScaffold(
        childPad: false,
        header: FHeader.nested(
          title: Text(title),
          prefixes: context.canPop()
              ? [FHeaderAction.back(onPress: context.pop)]
              : const [],
        ),
        child: const Center(child: FCircularProgress()),
      );
    }
    final key = _key(currentUserId);
    final state = ref.watch(messageThreadProvider(key));
    final notifier = ref.read(messageThreadProvider(key).notifier);

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(title),
        prefixes: context.canPop()
            ? [FHeaderAction.back(onPress: context.pop)]
            : const [],
      ),
      child: Column(
        children: [
          Expanded(child: _buildMessages(state, notifier, currentUserId)),
          if (state.sendError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FAlert(
                      variant: FAlertVariant.destructive,
                      title: Text(state.sendError!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress: state.isSending
                        ? null
                        : () async {
                            final sent = await notifier.retryFailed();
                            if (sent && mounted) _controller.clear();
                          },
                    child: const Icon(
                      FLucideIcons.refreshCw,
                      semanticLabel: '重试发送',
                    ),
                  ),
                ],
              ),
            ),
          if (state.readError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FAlert(
                      variant: FAlertVariant.destructive,
                      title: Text('标记已读失败: ${state.readError}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress: state.isMarkingRead
                        ? null
                        : notifier.retryMarkRead,
                    child: state.isMarkingRead
                        ? const FCircularProgress(size: .sm)
                        : const Icon(
                            FLucideIcons.refreshCw,
                            semanticLabel: '重试标记已读',
                          ),
                  ),
                ],
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
                      maxLines: 4,
                      maxLength: 4000,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress: state.isSending || currentUserId <= 0
                        ? null
                        : () => _send(key),
                    child: state.isSending
                        ? const FCircularProgress(size: .sm)
                        : const Icon(FLucideIcons.send, semanticLabel: '发送'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessages(
    MessageThreadState state,
    MessageThreadNotifier notifier,
    int currentUserId,
  ) {
    if (state.isLoading && state.messages.isEmpty) {
      return const Center(child: FCircularProgress());
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorView(message: state.error!, onRetry: notifier.refresh);
    }
    if (state.messages.isEmpty) {
      return const EmptyView(message: '暂无消息', icon: FLucideIcons.messageCircle);
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: state.messages.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.hasMore && index == 0) {
          return Center(
            child: FButton.icon(
              variant: FButtonVariant.ghost,
              onPress: state.isLoadingOlder ? null : notifier.loadOlder,
              child: state.isLoadingOlder
                  ? const FCircularProgress(size: .sm)
                  : const Icon(
                      FLucideIcons.chevronsUp,
                      semanticLabel: '加载更早消息',
                    ),
            ),
          );
        }
        final messageIndex = index - (state.hasMore ? 1 : 0);
        return _MessageBubble(
          message: state.messages[messageIndex],
          own: state.messages[messageIndex].senderId == currentUserId,
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final DirectMessage message;
  final bool own;

  const _MessageBubble({required this.message, required this.own});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.72,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: own ? theme.colors.primary : theme.colors.secondary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message.content,
                    style: theme.typography.body.md.copyWith(
                      color: own
                          ? theme.colors.primaryForeground
                          : theme.colors.secondaryForeground,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _messageTime(message.createdAt),
                    style: theme.typography.body.xs.copyWith(
                      color:
                          (own
                                  ? theme.colors.primaryForeground
                                  : theme.colors.secondaryForeground)
                              .withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _messageTime(int seconds) {
  if (seconds <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
