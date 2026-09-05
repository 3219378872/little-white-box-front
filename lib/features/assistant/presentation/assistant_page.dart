import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../post/data/post_repository.dart';
import '../application/assistant_notifier.dart';
import '../application/assistant_thread_notifier.dart';
import '../data/assistant_models.dart';
import 'assistant_runtime_widgets.dart';
import 'assistant_research_widgets.dart';
import 'streaming_markdown.dart';

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

const _maxImageBytes = 10 * 1024 * 1024;

final assistantImagePickerProvider = Provider<ImagePicker>((ref) {
  return ImagePicker();
});

final assistantAttachmentRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository();
});

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
  final ValueChanged<AssistantSourceCard>? onOpenSource;
  final Object contextPostId;

  const AssistantPage({super.key, this.onOpenSource, this.contextPostId = 0});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  var _loadedIdentity = '';
  var _pinnedToBottom = true;
  var _scrollScheduled = false;
  var _sendAttempt = 0;
  var _sendBusy = false;

  void _scheduleLoad(String identity) {
    if (identity == _loadedIdentity) return;
    _loadedIdentity = identity;
    _sendAttempt++;
    _sendBusy = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _loadedIdentity != identity ||
          ref.read(assistantUserKeyProvider) != identity) {
        return;
      }
      _controller.clear();
      if (identity.isEmpty) return;
      ref.read(agentConsentNotifierProvider.notifier).ensureLoaded();
      ref.read(assistantNotifierProvider.notifier).load();
    });
  }

  bool _ownsAssistantIdentity(String identity) {
    return mounted &&
        identity.isNotEmpty &&
        ref.read(assistantUserKeyProvider) == identity;
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _recoverAuthorization() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsAssistantIdentity(identity)) return;
    final agreed = await _showAgentConsentDialog();
    if (!mounted || !agreed || !_ownsAssistantIdentity(identity)) return;
    try {
      await ref.read(agentConsentNotifierProvider.notifier).grant();
      if (!mounted || !_ownsAssistantIdentity(identity)) return;
      await ref.read(assistantNotifierProvider.notifier).retryPending();
    } on ApiException catch (error) {
      if (!mounted || !_ownsAssistantIdentity(identity)) return;
      showAppError(context, friendlyErrorMessage(error));
    }
  }

  Future<void> _send() async {
    if (_sendBusy) return;
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsAssistantIdentity(identity)) return;
    final attempt = ++_sendAttempt;
    setState(() => _sendBusy = true);
    try {
      final current = ref.read(assistantNotifierProvider);
      if (!current.isLoaded || current.isLoadingHistory) return;
      final text = _controller.text;
      await ref.read(agentConsentNotifierProvider.notifier).ensureLoaded();
      if (!_ownsAssistantIdentity(identity)) return;
      final status = ref.read(agentConsentNotifierProvider);
      if (!status.canStartRun) {
        final agreed = await _showAgentConsentDialog(
          upgrade: status.needsUpgrade,
        );
        if (!mounted || !agreed || !_ownsAssistantIdentity(identity)) return;
        try {
          await ref.read(agentConsentNotifierProvider.notifier).grant();
          if (!mounted || !_ownsAssistantIdentity(identity)) return;
        } on ApiException catch (error) {
          if (mounted && _ownsAssistantIdentity(identity)) {
            showAppError(context, friendlyErrorMessage(error));
          }
          return;
        }
      }
      final accepted = await ref
          .read(assistantNotifierProvider.notifier)
          .send(text, contextPostId: widget.contextPostId);
      if (_ownsAssistantIdentity(identity) &&
          accepted &&
          _controller.text == text) {
        _controller.clear();
      }
    } finally {
      if (mounted && attempt == _sendAttempt) {
        setState(() => _sendBusy = false);
      }
    }
  }

  Future<void> _revokeAuthorization() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsAssistantIdentity(identity)) return;
    var confirmed = false;
    await showFDialog<void>(
      context: context,
      builder: (dialogContext, dialogStyle, animation) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('撤销 Agent 授权', style: dialogStyle.titleTextStyle),
            const SizedBox(height: 8),
            Text(
              '撤销后不能发送新请求，也不能使用记忆和追踪；历史消息仍会保留。',
              style: dialogStyle.bodyTextStyle,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.of(dialogContext).pop(),
                  child: const Text('保留授权'),
                ),
                const SizedBox(width: 8),
                FButton(
                  key: const Key('assistant-confirm-revoke-consent'),
                  variant: .destructive,
                  onPress: () {
                    confirmed = true;
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('撤销授权'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    if (!mounted || !confirmed || !_ownsAssistantIdentity(identity)) return;
    try {
      await ref.read(agentConsentNotifierProvider.notifier).revoke();
      if (mounted && _ownsAssistantIdentity(identity)) {
        showAppSuccess(context, 'Agent 授权已撤销');
      }
    } catch (error) {
      if (mounted && _ownsAssistantIdentity(identity)) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  Future<bool> _showAgentConsentDialog({bool upgrade = false}) async {
    var agreed = false;
    final status = ref.read(agentConsentNotifierProvider);
    final version = status.currentVersion == 0 ? 2 : status.currentVersion;
    await showFDialog<void>(
      context: context,
      builder: (dialogContext, dialogStyle, animation) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              upgrade ? '升级 Agent 授权' : '启用小白盒 Agent',
              style: dialogStyle.titleTextStyle,
            ),
            const SizedBox(height: 8),
            Text(
              '当前披露版本 $version。\n$agentConsentDisclosure',
              style: dialogStyle.bodyTextStyle,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FButton(
                  variant: .outline,
                  onPress: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FButton(
                  variant: .primary,
                  onPress: () {
                    agreed = true;
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: Text(upgrade ? '同意并升级' : '同意并启用'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return agreed;
  }

  Future<void> _dislikeCard(AssistantSourceCard card) async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!card.isVerifiedPost ||
        card.postId == null ||
        !_ownsAssistantIdentity(identity)) {
      return;
    }
    try {
      await ref
          .read(assistantRepositoryProvider)
          .submitRecommendFeedback(postId: card.postId!, reason: 'dislike');
      if (mounted && _ownsAssistantIdentity(identity)) {
        showAppSuccess(context, '已记录反馈');
      }
    } catch (error) {
      if (mounted && _ownsAssistantIdentity(identity)) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _pickAttachment() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsAssistantIdentity(identity)) return;
    final file = await ref
        .read(assistantImagePickerProvider)
        .pickImage(source: ImageSource.gallery);
    if (file == null || !mounted || !_ownsAssistantIdentity(identity)) return;
    try {
      final bytes = await file.readAsBytes();
      if (!mounted || !_ownsAssistantIdentity(identity)) return;
      if (bytes.length > _maxImageBytes) {
        showAppError(context, '图片不能超过 10 MiB');
        return;
      }
      final uploaded = await ref
          .read(assistantAttachmentRepositoryProvider)
          .uploadImageMultipart(bytes: bytes, filename: file.name);
      if (!mounted || !_ownsAssistantIdentity(identity)) return;
      ref
          .read(assistantNotifierProvider.notifier)
          .addPendingAttachment(
            PendingChatImage(
              mediaId: uploaded.mediaId,
              url: uploaded.url,
              thumbnailUrl: uploaded.thumbnailUrl,
            ),
          );
    } catch (error) {
      if (mounted && _ownsAssistantIdentity(identity)) {
        showAppError(context, '图片上传失败: ${friendlyErrorMessage(error)}');
      }
    }
  }

  void _openSource(AssistantSourceCard source) {
    final callback = widget.onOpenSource;
    if (callback != null) {
      callback(source);
      return;
    }
    if (source.isVerifiedPost) {
      context.push('/post/${jsonInt64Id(source.authorityId)}');
    }
  }

  bool _canOpen(AssistantSourceCard source) {
    return widget.onOpenSource != null || source.isVerifiedPost;
  }

  void _onRevealed() {
    _schedulePinScroll(jump: true);
  }

  void _onStructuralMessageChange() {
    _schedulePinScroll(jump: false);
  }

  void _schedulePinScroll({required bool jump}) {
    if (!_pinnedToBottom || _scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_pinnedToBottom || !_scrollController.hasClients) {
        return;
      }
      final max = _scrollController.position.maxScrollExtent;
      if (jump) {
        _scrollController.jumpTo(max);
      } else {
        _scrollController.animateTo(
          max,
          duration: const Duration(milliseconds: 80),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Widget _buildConversationBody(AssistantState state) {
    if (!state.isLoaded || (state.isLoadingHistory && state.messages.isEmpty)) {
      return const Center(
        key: Key('assistant-initial-loading'),
        child: FCircularProgress(),
      );
    }
    if (state.messages.isEmpty) {
      final error = state.connectionError;
      if (error != null) {
        return ErrorView(
          key: const Key('assistant-initial-error'),
          message: error,
          onRetry: ref.read(assistantNotifierProvider.notifier).load,
        );
      }
      return const EmptyView(
        key: Key('assistant-empty'),
        message: '开始新的对话',
        icon: FLucideIcons.sparkles,
      );
    }
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (!_scrollController.hasClients) return false;
        final pos = _scrollController.position;
        _pinnedToBottom = (pos.maxScrollExtent - pos.pixels) <= 48;
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          final runKey = 'run-${jsonInt64Id(state.activeRunId)}';
          final isStreaming =
              message.isStreaming ||
              (state.isStreaming && message.id == runKey);
          return _AssistantMessageBubble(
            key: ValueKey(message.id),
            message: message,
            isStreaming: isStreaming,
            onRevealed: _onRevealed,
            canOpenSource: _canOpen,
            onOpenSource: _openSource,
            onConfirm: (callId, approved) => ref
                .read(assistantNotifierProvider.notifier)
                .respondToConfirmation(callId, approved),
            onDislikeCard: _dislikeCard,
            onAnswerQuestion: (question, answers, continueExpired) => ref
                .read(assistantNotifierProvider.notifier)
                .answerQuestion(
                  question,
                  answers,
                  continueExpired: continueExpired,
                ),
            onUndo: (changeId) => ref
                .read(assistantNotifierProvider.notifier)
                .undoMemoryChange(changeId),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.watch(assistantUserKeyProvider);
    final state = ref.watch(assistantNotifierProvider);
    final consent = ref.watch(agentConsentNotifierProvider);
    _scheduleLoad(identity);
    ref.listen<AssistantState>(assistantNotifierProvider, (previous, next) {
      if (previous != null &&
          !previous.agentAuthorizationRequired &&
          next.agentAuthorizationRequired) {
        unawaited(_recoverAuthorization());
      }
      if (next.messages.isNotEmpty &&
          (previous == null ||
              previous.messages.isEmpty ||
              previous.messages.last.id != next.messages.last.id ||
              !identical(previous.messages.last, next.messages.last))) {
        _onStructuralMessageChange();
      }
    });
    ref.listen<AssistantThreadState>(assistantThreadProvider, (previous, next) {
      if (next.isLoading) return;
      unawaited(
        ref
            .read(assistantNotifierProvider.notifier)
            .refreshForThread(next.thread),
      );
    });

    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('小白盒 Agent'),
        suffixes: [
          if (consent.loaded && consent.granted)
            FHeaderAction(
              key: const Key('assistant-revoke-consent'),
              icon: const Icon(FLucideIcons.shieldOff),
              semanticsLabel: '撤销 Agent 授权',
              onPress: _revokeAuthorization,
            ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.brain),
            semanticsLabel: '记忆',
            onPress: () => context.push('/messages/assistant/memory'),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.bell),
            semanticsLabel: '追踪',
            onPress: () => context.push('/messages/assistant/watch'),
          ),
          FHeaderAction(
            key: const Key('assistant-clear-history'),
            icon: const Icon(FLucideIcons.trash2),
            semanticsLabel: '清除历史',
            onPress:
                !state.isLoaded || state.isLoadingHistory || state.isSending
                ? null
                : () => ref
                      .read(assistantNotifierProvider.notifier)
                      .clearHistory(),
          ),
        ],
      ),
      child: Column(
        children: [
          if (state.hasMoreHistory ||
              state.isLoadingOlder ||
              state.historyError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Column(
                children: [
                  FButton(
                    key: const Key('assistant-load-older'),
                    variant: .ghost,
                    size: .sm,
                    onPress: state.isLoadingHistory || state.isLoadingOlder
                        ? null
                        : ref
                              .read(assistantNotifierProvider.notifier)
                              .loadOlderMessages,
                    child: Text(state.isLoadingOlder ? '正在加载…' : '加载更早消息'),
                  ),
                  if (state.historyError != null)
                    Text(
                      state.historyError!,
                      style: context.theme.typography.body.xs.copyWith(
                        color: context.theme.colors.destructive,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(child: _buildConversationBody(state)),
          if (state.messages.isNotEmpty && state.connectionError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: FAlert(
                variant: FAlertVariant.destructive,
                title: Text(state.connectionError!),
                subtitle: state.hasActiveRun && !state.isStreaming
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: FButton(
                          key: const Key('assistant-reconnect'),
                          variant: .outline,
                          size: .sm,
                          onPress: ref
                              .read(assistantNotifierProvider.notifier)
                              .reconnectActiveRun,
                          child: const Text('重新连接'),
                        ),
                      )
                    : null,
              ),
            ),
          if (state.isQueued || state.hasActiveRun || state.isStreaming)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FBadge(
                  variant: .secondary,
                  child: Text(_busyLabel(state)),
                ),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (consent.loaded && consent.granted)
                        FBadge(
                          variant: .secondary,
                          child: Text(
                            consent.needsUpgrade
                                ? '授权待升级 v${consent.consentVersion}'
                                : 'Agent 已授权 v${consent.consentVersion}',
                            style: context.theme.typography.body.xs,
                          ),
                        ),
                    ],
                  ),
                  if (state.pendingAttachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PendingAttachmentRow(state: state),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FButton.icon(
                        key: const Key('assistant-add-attachment'),
                        variant: .ghost,
                        onPress:
                            state.isLoaded &&
                                !state.isLoadingHistory &&
                                !state.isSending &&
                                !_sendBusy
                            ? _pickAttachment
                            : null,
                        child: const Icon(
                          FLucideIcons.imagePlus,
                          semanticLabel: '添加图片附件',
                        ),
                      ),
                      const SizedBox(width: 4),
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
                      if (state.hasActiveRun || state.isStreaming) ...[
                        FButton.icon(
                          key: const Key('assistant-stop'),
                          variant: FButtonVariant.secondary,
                          onPress: ref
                              .read(assistantNotifierProvider.notifier)
                              .stop,
                          child: const Icon(
                            FLucideIcons.square,
                            semanticLabel: '停止生成',
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      FButton.icon(
                        key: const Key('assistant-send-or-stop'),
                        variant: FButtonVariant.primary,
                        onPress:
                            state.isLoaded &&
                                !state.isLoadingHistory &&
                                state.canSend &&
                                !_sendBusy
                            ? _send
                            : null,
                        child: const Icon(
                          FLucideIcons.send,
                          semanticLabel: '发送',
                        ),
                      ),
                    ],
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

String _busyLabel(AssistantState state) {
  if (state.activeRunPhase == 'waiting_input') {
    return '等待回答';
  }
  if (state.isQueued || state.lastDisposition == AssistantDisposition.queued) {
    return '已排队，等待当前任务可注入';
  }
  return switch (state.lastDisposition) {
    AssistantDisposition.redirected => '已转向新的回答',
    AssistantDisposition.steered => '已注入当前任务',
    AssistantDisposition.started =>
      state.activeRunPhase == 'tool_executing' ? '正在使用工具' : '正在思考',
    _ => state.activeRunPhase == 'tool_executing' ? '正在使用工具' : '处理中',
  };
}

class _PendingAttachmentRow extends ConsumerWidget {
  final AssistantState state;

  const _PendingAttachmentRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in state.pendingAttachments)
          Stack(
            children: [
              ClipRRect(
                borderRadius: theme.style.borderRadius.md,
                child: Image.network(
                  image.thumbnailUrl.isNotEmpty
                      ? image.thumbnailUrl
                      : image.url,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: FButton.icon(
                  variant: .destructive,
                  size: .xs,
                  onPress: () => ref
                      .read(assistantNotifierProvider.notifier)
                      .removePendingAttachment(image.mediaId),
                  child: const Icon(
                    FLucideIcons.x,
                    size: 12,
                    semanticLabel: '移除附件',
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

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
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  if (message.toolSteps.isNotEmpty) ...[
                    for (final step in message.toolSteps.where(
                      (step) => step.tool != 'ask_questions',
                    ))
                      _ToolStepEntry(step: step, onConfirm: onConfirm),
                    if (bodyText.isNotEmpty || isStreaming)
                      const SizedBox(height: 8),
                  ],
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
                  if (isStreaming &&
                      message.questionRequest == null &&
                      message.answerPresentation == null) ...[
                    if (bodyText.isNotEmpty) const SizedBox(height: 8),
                    const FCircularProgress(size: .sm),
                  ],
                  AssistantSourceCards(
                    message: message,
                    canOpen: canOpenSource,
                    onOpen: onOpenSource,
                    onDislike: onDislikeCard ?? (_) {},
                  ),
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

class _ToolStepEntry extends StatelessWidget {
  final AssistantToolStep step;
  final void Function(String callId, bool approved)? onConfirm;

  const _ToolStepEntry({required this.step, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final awaiting = step.status == AssistantToolStatus.awaitingConfirmation;
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
                      variant: .destructive,
                      size: .sm,
                      onPress: onConfirm == null
                          ? null
                          : () => onConfirm!(step.callId, true),
                      child: const Text('确认删除'),
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
