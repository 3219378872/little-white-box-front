import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_notifier.dart';
import '../../post/data/post_repository.dart';
import '../application/message_notifiers.dart';
import '../data/message_models.dart';

class MessageThreadPage extends ConsumerStatefulWidget {
  final Object conversationId;
  final Object targetUserId;
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

  MessageThreadKey _key(Object currentUserId) => MessageThreadKey(
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

  Future<void> _sendImage(MessageThreadKey key) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        if (mounted) showAppError(context, '图片不能超过 10 MiB');
        return;
      }
      final uploaded = await PostRepository().uploadImageMultipart(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
      final sent = await ref
          .read(messageThreadProvider(key).notifier)
          .send(
            uploaded.url,
            msgType: MessageTypes.image,
            mediaId: uploaded.mediaId,
          );
      if (sent) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
      }
    } catch (error) {
      if (mounted) {
        showAppError(context, '图片发送失败: ${friendlyErrorMessage(error)}');
      }
    }
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
    final currentUserId = auth.userId;
    if (auth.isLoading || !jsonInt64IsPositive(currentUserId)) {
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
    final key = _key(currentUserId!);
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
          Expanded(child: _buildMessages(state, notifier, currentUserId!)),
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
                      maxLength: 1000,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress: state.isSending || !jsonInt64IsPositive(currentUserId)
                        ? null
                        : () => _sendImage(key),
                    child: const Icon(
                      FLucideIcons.image,
                      semanticLabel: '发送图片',
                    ),
                  ),
                  FButton.icon(
                    onPress: null,
                    child: const Icon(
                      FLucideIcons.video,
                      semanticLabel: '视频发送暂不可用',
                    ),
                  ),
                  FButton.icon(
                    onPress: null,
                    child: const Icon(
                      FLucideIcons.mic,
                      semanticLabel: '语音发送暂不可用',
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress: state.isSending || !jsonInt64IsPositive(currentUserId)
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
    Object currentUserId,
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
          own:
              jsonInt64Id(state.messages[messageIndex].senderId) ==
              jsonInt64Id(currentUserId),
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
                  _MessageBody(message: message, own: own),
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

class _MessageBody extends StatelessWidget {
  final DirectMessage message;
  final bool own;

  const _MessageBody({required this.message, required this.own});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final foreground = own
        ? theme.colors.primaryForeground
        : theme.colors.secondaryForeground;
    final looksLikeUrl =
        message.content.startsWith('http://') ||
        message.content.startsWith('https://');
    if (message.msgType == MessageTypes.image && looksLikeUrl) {
      return ClipRRect(
        borderRadius: theme.style.borderRadius.md,
        child: CachedNetworkImage(
          imageUrl: message.content,
          fit: BoxFit.cover,
          width: 220,
        ),
      );
    }
    if ((message.msgType == MessageTypes.video ||
            message.msgType == MessageTypes.audio) &&
        looksLikeUrl) {
      return Text(
        message.msgType == MessageTypes.video ? '视频消息' : '语音消息',
        style: theme.typography.body.md.copyWith(color: foreground),
      );
    }
    if (message.msgType != MessageTypes.text && !looksLikeUrl) {
      return Text(
        '媒体不可用',
        style: theme.typography.body.md.copyWith(color: foreground),
      );
    }
    return Text(
      message.content,
      style: theme.typography.body.md.copyWith(color: foreground),
    );
  }
}

String _messageTime(int seconds) {
  if (seconds <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
