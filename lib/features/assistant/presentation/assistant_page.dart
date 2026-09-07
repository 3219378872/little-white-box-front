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

part 'assistant_message_widgets.dart';
part 'assistant_page_controls.dart';

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
        message: '暂无消息',
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
      header: _buildAssistantHeader(state, consent),
      child: Column(
        children: [
          if (state.hasMoreHistory ||
              state.isLoadingOlder ||
              state.historyError != null)
            _buildHistoryControl(state),
          Expanded(child: _buildConversationBody(state)),
          if (state.messages.isNotEmpty && state.connectionError != null)
            _buildConnectionStatus(state),
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
          _buildComposer(state, consent),
        ],
      ),
    );
  }
}
