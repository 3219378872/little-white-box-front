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
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_notifier.dart';
import '../../media/data/media_repository.dart';
import '../application/media_send_controller.dart';
import '../application/message_providers.dart';
import '../application/message_thread_notifier.dart';
import '../data/message_models.dart';
import '../../media/application/media_dependencies.dart';
import 'stick_to_latest_scroll.dart';
import 'widgets/inline_error_bar.dart';
import 'widgets/media_picker_bar.dart';
import 'widgets/pending_media_row.dart';
import 'widgets/thread_composer.dart';
import '../../../core/router/app_routes.dart';

/// 与单个用户的私信线程页：消息列表、文本与媒体发送、发送/已读失败的重试入口。
///
/// 路由参数里的 ID 可能是 int 或十进制字符串，页面内统一按 [jsonInt64Id] 比较。
class MessageThreadPage extends ConsumerStatefulWidget {
  /// 会话 ID，来自路由参数。
  final Object conversationId;

  /// 对方用户 ID，发送消息时作为接收者。
  final Object targetUserId;

  /// 对方昵称，仅用于页头；为空时显示「用户 {id}」。
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

// 持有输入草稿、贴底滚动与媒体发送任务，并在会话或登录身份变化时整体重置它们。
class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _controller = TextEditingController();
  final _scroll = StickToLatestScroll();
  late final MediaSendController _media;
  // 正在打开系统文件选择器，期间锁定媒体入口。
  bool _selecting = false;
  // 页面归属代次：会话、对方用户或登录身份变化时递增，作废进行中的选择与发送。
  int _ownerGeneration = 0;

  @override
  void initState() {
    super.initState();
    _media = MediaSendController(ref.read(mediaRepositoryProvider))
      ..addListener(_mediaChanged);
    // 登录会话或用户变化时作废进行中的媒体任务与输入，防止串号发送。
    ref.listenManual(authNotifierProvider, (previous, next) {
      if (previous != null &&
          (previous.sessionRevision != next.sessionRevision ||
              jsonInt64Id(previous.userId) != jsonInt64Id(next.userId))) {
        _resetOwner();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MessageThreadPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同一页面实例被复用到另一个会话时，重置归属。
    if (jsonInt64Id(oldWidget.conversationId) !=
            jsonInt64Id(widget.conversationId) ||
        jsonInt64Id(oldWidget.targetUserId) !=
            jsonInt64Id(widget.targetUserId)) {
      _resetOwner();
    }
  }

  // A picker can outlive the route without having created a media task yet.
  // Invalidate it as well as uploads and retained retries on every owner change.
  void _resetOwner() {
    _ownerGeneration++;
    _selecting = false;
    _scroll.reset();
    _controller.clear();
    _media.cancel();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _media.dispose();
    _controller.dispose();
    super.dispose();
  }

  // 以当前登录用户构造线程 provider 的键。
  MessageThreadKey _key(Object currentUserId) => MessageThreadKey(
    conversationId: widget.conversationId,
    targetUserId: widget.targetUserId,
    currentUserId: currentUserId,
  );

  // 发送成功且输入框未被改动时才清空，避免吞掉用户在请求期间新输入的内容。
  Future<void> _send(MessageThreadKey key) async {
    final text = _controller.text;
    final sent = await ref.read(messageThreadProvider(key).notifier).send(text);
    if (!mounted || !sent) return;
    if (_controller.text == text) _controller.clear();
    _scroll.animateToLatestAfterFrame();
  }

  // 重发失败的文本：只有输入框仍是那条失败内容时才清空。
  Future<void> _retryFailedSend(
    MessageThreadNotifier notifier,
    SendMessageCommand? command,
  ) async {
    final text = _controller.text;
    final sent = await notifier.retryFailed();
    if (sent &&
        mounted &&
        _controller.text == text &&
        command?.content == text.trim()) {
      _controller.clear();
    }
  }

  // 媒体任务进度或错误变化时重建。
  void _mediaChanged() {
    if (mounted) setState(() {});
  }

  // 选择 → 上传 → 发送一条媒体消息；任何一步之后页面、会话或登录身份变化都放弃后续步骤。
  Future<void> _sendMedia(MessageThreadKey key, MediaKind kind) async {
    final auth = ref.read(authNotifierProvider);
    final ownerGeneration = _ownerGeneration;
    bool current() =>
        mounted &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        ownerGeneration == _ownerGeneration &&
        jsonInt64Id(widget.conversationId) == key.conversationId &&
        jsonInt64Id(widget.targetUserId) == key.targetUserId &&
        ref.read(authNotifierProvider).isAuthenticated &&
        ref.read(authNotifierProvider).sessionRevision ==
            auth.sessionRevision &&
        ref.read(authNotifierProvider).userId == auth.userId;
    // 选择文件，再把上传与发送交给媒体任务；发送回调里再次确认归属未变。
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
          if (sent && current()) _scroll.revealLatest();
          return sent;
        },
      );
    } catch (e) {
      if (mounted && current()) showAppError(context, friendlyErrorMessage(e));
    } finally {
      if (mounted && ownerGeneration == _ownerGeneration) {
        setState(() => _selecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    final title = widget.targetUserName.isEmpty
        ? '用户 ${widget.targetUserId}'
        : widget.targetUserName;
    final currentUserId = auth.userId;
    // 身份恢复中或未登录：只渲染页头与加载态，不创建线程 provider。
    if (auth.isLoading || !jsonInt64IsPositive(currentUserId)) {
      return FScaffold(
        childPad: false,
        header: FHeader.nested(
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          prefixes: [
            FHeaderAction.back(
              onPress: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.messages),
            ),
          ],
        ),
        child: const LoadingView(),
      );
    }
    final key = _key(currentUserId!);
    final state = ref.watch(messageThreadProvider(key));
    final notifier = ref.read(messageThreadProvider(key).notifier);
    // 每次构建报告消息数，让贴底滚动决定是否跟随新消息。
    _scroll.follow(state.messages.length);
    // 有媒体在选择、上传或待重试时，锁住媒体入口与文本发送，避免两条发送交错。
    final mediaLocked = _selecting || _media.busy || _media.hasPending;

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        prefixes: [
          FHeaderAction.back(
            onPress: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.messages),
          ),
        ],
      ),
      child: Column(
        children: [
          // 消息列表
          Expanded(child: _buildMessages(state, notifier, currentUserId)),
          // 待发送媒体的失败由下方媒体行负责展示，避免同一失败出现两条横幅。
          if (state.sendError != null && !_media.hasPending)
            InlineErrorBar(
              message: state.sendError!,
              retryLabel: '重试发送',
              onRetry: state.isSending
                  ? null
                  : () => _retryFailedSend(notifier, state.failedCommand),
            ),
          // 标记已读失败横幅
          if (state.readError != null)
            InlineErrorBar(
              message: '标记已读失败: ${state.readError}',
              retryLabel: '重试标记已读',
              retrying: state.isMarkingRead,
              onRetry: state.isMarkingRead ? null : notifier.retryMarkRead,
            ),
          // 媒体入口、待发送媒体的失败行与文本输入框。
          MediaPickerBar(
            enabled: !state.isSending && !mediaLocked,
            busy: _media.busy || _selecting,
            onPick: (kind) => _sendMedia(key, kind),
          ),
          if (_media.error != null)
            PendingMediaRow(
              error: _media.error!,
              busy: _media.busy,
              onRetry: _media.retry,
              onCancel: () {
                _media.cancel();
                notifier.discardFailedMedia();
              },
            ),
          ThreadComposer(
            controller: _controller,
            sending: state.isSending,
            onSend: state.isSending || mediaLocked ? null : () => _send(key),
          ),
        ],
      ),
    );
  }

  // 首屏加载/错误/空态之外渲染消息列表；还有更早消息时首行放“加载更早”按钮。
  Widget _buildMessages(
    MessageThreadState state,
    MessageThreadNotifier notifier,
    Object currentUserId,
  ) {
    if (state.isLoading && state.messages.isEmpty) {
      return const LoadingView();
    }
    if (state.error != null && state.messages.isEmpty) {
      return ErrorView(message: state.error!, onRetry: notifier.loadInitial);
    }
    if (state.messages.isEmpty) {
      return const EmptyView(message: '暂无消息', icon: FLucideIcons.messageCircle);
    }
    return ListView.builder(
      controller: _scroll.controller,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      itemCount: state.messages.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 首行：加载更早消息。
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

// 单条消息气泡：自己发的靠右用主色，对方的靠左用次色，底部附发送时间。
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

// 按消息类型渲染正文：图片直接显示，音视频交给系统打开，非 URL 的媒体内容提示不可用。
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
    // 媒体消息的正文应是 http(s) URL，否则无法渲染。
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
    // 媒体消息缺少有效 URL 时给出提示，而不是把原始内容当文本展示。
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
