import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_notifier.dart';
import '../../media/data/media_repository.dart';
import '../application/media_send_controller.dart';
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
  bool _pinToLatest = true;
  int _seenMessageCount = 0;
  late final MediaSendController _media;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _media = MediaSendController(ref.read(mediaRepositoryProvider))
      ..addListener(_mediaChanged);
    _scrollController.addListener(_rememberPin);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_rememberPin);
    _media.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _rememberPin() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _pinToLatest = position.maxScrollExtent - position.pixels <= 48;
  }

  void _revealLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if ((_scrollController.offset - target).abs() < 1) return;
      _scrollController.jumpTo(target);
    });
  }

  MessageThreadKey _key(Object currentUserId) => MessageThreadKey(
    conversationId: widget.conversationId,
    targetUserId: widget.targetUserId,
    currentUserId: currentUserId,
  );

  Future<void> _send(MessageThreadKey key) async {
    final text = _controller.text;
    final sent = await ref.read(messageThreadProvider(key).notifier).send(text);
    if (!mounted || !sent) return;
    if (_controller.text == text) _controller.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToEnd());
  }

  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _sendMedia(MessageThreadKey key, MediaKind kind) async {
    final auth = ref.read(authNotifierProvider);
    bool current() =>
        mounted &&
        ref.read(authNotifierProvider).isAuthenticated &&
        ref.read(authNotifierProvider).sessionRevision ==
            auth.sessionRevision &&
        ref.read(authNotifierProvider).userId == auth.userId;
    setState(() => _selecting = true);
    try {
      final file = await ref.read(mediaPickerProvider).pick(kind);
      if (file == null || !current()) return;
      await _media.start(
        file,
        kind,
        isCurrent: current,
        send: (uploaded, selectedKind) async {
          if (!current()) return false;
          final sent = await ref
              .read(messageThreadProvider(key).notifier)
              .send(
                uploaded.url,
                msgType: selectedKind.messageType,
                mediaId: uploaded.mediaId,
              );
          if (sent && current()) _revealLatest();
          return sent;
        },
      );
    } catch (e) {
      if (mounted && current()) showAppError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _selecting = false);
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
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          prefixes: [
            FHeaderAction.back(
              onPress: () =>
                  context.canPop() ? context.pop() : context.go('/messages'),
            ),
          ],
        ),
        child: const Center(child: FCircularProgress()),
      );
    }
    final key = _key(currentUserId!);
    final state = ref.watch(messageThreadProvider(key));
    final notifier = ref.read(messageThreadProvider(key).notifier);
    final messageCount = state.messages.length;
    if (messageCount != _seenMessageCount) {
      final opened = _seenMessageCount == 0 && messageCount > 0;
      _seenMessageCount = messageCount;
      if (opened || _pinToLatest) _revealLatest();
    }

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/messages'),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(child: _buildMessages(state, notifier, currentUserId)),
          if (state.sendError != null && !_media.hasPending)
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
                            final text = _controller.text;
                            final command = state.failedCommand;
                            final sent = await notifier.retryFailed();
                            if (sent &&
                                mounted &&
                                _controller.text == text &&
                                command?.content == text.trim()) {
                              _controller.clear();
                            }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                for (final kind in MediaKind.values) ...[
                  FButton.icon(
                    variant: FButtonVariant.ghost,
                    onPress:
                        state.isSending ||
                            _selecting ||
                            _media.busy ||
                            _media.hasPending
                        ? null
                        : () => _sendMedia(key, kind),
                    child: Icon(
                      switch (kind) {
                        MediaKind.image => FLucideIcons.image,
                        MediaKind.video => FLucideIcons.video,
                        MediaKind.audio => FLucideIcons.audioLines,
                      },
                      semanticLabel: switch (kind) {
                        MediaKind.image => '发送图片',
                        MediaKind.video => '发送视频',
                        MediaKind.audio => '发送语音文件',
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (_media.busy || _selecting)
                  const FCircularProgress(size: .sm),
              ],
            ),
          ),
          if (_media.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(child: Text(_media.error!)),
                  FButton.icon(
                    onPress: _media.busy ? null : _media.retry,
                    child: const Icon(
                      FLucideIcons.refreshCw,
                      semanticLabel: '重试媒体发送',
                    ),
                  ),
                  FButton.icon(
                    onPress: () {
                      _media.cancel();
                      notifier.discardFailedMedia();
                    },
                    child: const Icon(FLucideIcons.x, semanticLabel: '取消媒体发送'),
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
                    child: Semantics(
                      label: '消息',
                      child: FTextField.multiline(
                        control: FTextFieldControl.managed(
                          controller: _controller,
                        ),
                        hint: '输入消息',
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 1000,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FButton.icon(
                    onPress:
                        state.isSending ||
                            _media.busy ||
                            _media.hasPending ||
                            _selecting ||
                            !jsonInt64IsPositive(currentUserId)
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
              borderRadius: BorderRadius.circular(4),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _MessageBody(message: message, own: own),
                  const SizedBox(height: 3),
                  Text(
                    formatClockTime(message.createdAt),
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
      return FButton(
        variant: FButtonVariant.secondary,
        onPress: () async {
          try {
            if (!await launchUrl(
              Uri.parse(message.content),
              mode: LaunchMode.platformDefault,
            )) {
              if (context.mounted) showAppError(context, '无法打开媒体');
            }
          } catch (_) {
            if (context.mounted) showAppError(context, '无法打开媒体');
          }
        },
        child: Text(message.msgType == MessageTypes.video ? '打开视频' : '播放语音文件'),
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
