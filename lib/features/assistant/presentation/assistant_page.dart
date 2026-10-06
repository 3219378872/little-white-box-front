import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/assistant_notifier.dart';
import '../application/assistant_thread_notifier.dart';
import '../data/assistant_models.dart';
import 'assistant_page_controls.dart';
import 'assistant_runtime_widgets.dart';
import 'assistant_research_widgets.dart';
import 'streaming_markdown.dart';
import '../../../core/router/app_routes.dart';

part 'assistant_message_widgets.dart';

// 模型回复可能夹带的引用标记（[kind:id]、全角［post:…］）与工具证据行（SOURCE、
// COMMUNITY_CONTENT_JSON=、Community sources 标题）；来源已由卡片展示，渲染前剥掉。
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

// 附件图片上限 10 MiB，超出时本地拦截、不上传。
const _maxImageBytes = 10 * 1024 * 1024;

/// 渲染助手回复前清理正文：去掉证据行与引用标记，压缩多余空格与空行。
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

/// Agent 会话页：历史消息、流式回复、工具确认与输入区。[contextPostId] 让发送
/// 带上帖子上下文（路由查询参数传入）；[onOpenSource] 可替换来源的默认跳转。
class AssistantPage extends ConsumerStatefulWidget {
  final ValueChanged<AssistantSourceCard>? onOpenSource;
  final Object contextPostId;

  const AssistantPage({super.key, this.onOpenSource, this.contextPostId = 0});

  @override
  ConsumerState<AssistantPage> createState() => _AssistantPageState();
}

// 持有输入框、滚动与发送流程状态；异步回调返回后都复核登录身份，防止账号切换后串号。
class _AssistantPageState extends ConsumerState<AssistantPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  var _loadedIdentity = '';
  // 用户停在底部附近时，新内容到来自动滚到底。
  var _pinnedToBottom = true;
  var _scrollScheduled = false;
  // 发送流程代次：身份切换后，旧流程结束时不再复位 _sendBusy。
  var _sendAttempt = 0;
  var _sendBusy = false;

  // 登录身份变化（含首次构建）时，在下一帧清空输入并加载授权与历史。
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

  // 异步操作返回后确认页面仍挂载且登录身份未变。
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

  // 发送或 run 因未授权失败后弹出授权确认，同意则授权并重发待重试命令。
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

  // 发送：先确保授权（未授权或需升级时弹窗征求同意），再交给 notifier；
  // 受理后只在输入框内容未被改动时清空。
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
      // 授权门槛：未授权或授权版本落后时先征得同意。
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

  // 二次确认后撤销 Agent 授权。
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

  // 授权披露弹窗，返回用户是否同意；[upgrade] 为 true 时用升级授权的文案。
  Future<bool> _showAgentConsentDialog({bool upgrade = false}) async {
    var agreed = false;
    final status = ref.read(agentConsentNotifierProvider);
    final version = status.currentVersion == 0 ? 3 : status.currentVersion;
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

  // 对站内帖子来源提交「不喜欢」推荐反馈。
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

  // 从相册选图，校验大小后上传，成功后加入待发附件。
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

  // 打开来源：优先交给外部回调，否则站内帖子进详情页。
  void _openSource(AssistantSourceCard source) {
    final callback = widget.onOpenSource;
    if (callback != null) {
      callback(source);
      return;
    }
    if (source.isVerifiedPost) {
      context.push(AppRoutes.postDetail(source.authorityId));
    }
  }

  // 来源卡片是否提供「打开帖子」。
  bool _canOpen(AssistantSourceCard source) {
    return widget.onOpenSource != null || source.isVerifiedPost;
  }

  // 打字机露出新字时直接跳到底部（逐帧触发，不做滚动动画）。
  void _onRevealed() {
    _schedulePinScroll(jump: true);
  }

  // 末条消息新增或替换时平滑滚到底部。
  void _onStructuralMessageChange() {
    _schedulePinScroll(jump: false);
  }

  // 仅在用户贴底时滚动；同一帧内的多次请求合并为一次。
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

  // 会话主体：首次加载、空态/错误态与消息列表。
  Widget _buildConversationBody(AssistantState state) {
    if (!state.isLoaded || (state.isLoadingHistory && state.messages.isEmpty)) {
      return const LoadingView(key: Key('assistant-initial-loading'));
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
    // 用户滚动时记录是否仍贴底（距底部 48 像素以内）。
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
          // 活跃 run 的回复占位在流式期间也显示进行中。
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
    // 发送或 run 因未授权失败时发起授权恢复；末条消息变化时贴底滚动。
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
    // 线程摘要轮询结果交给 notifier 对账（阶段、新消息、run 结束）。
    ref.listen<AssistantThreadState>(assistantThreadProvider, (previous, next) {
      if (next.isLoading) return;
      unawaited(
        ref
            .read(assistantNotifierProvider.notifier)
            .refreshForThread(next.thread),
      );
    });

    final notifier = ref.read(assistantNotifierProvider.notifier);
    // 外围控件只拿状态与回调；需要在点击时才读取 provider 的回调用闭包延迟读取。
    return FScaffold(
      childPad: false,
      header: AssistantPageHeader(
        state: state,
        consent: consent,
        onClearHistory: () =>
            ref.read(assistantNotifierProvider.notifier).clearHistory(),
        onRevokeConsent: _revokeAuthorization,
      ),
      child: Column(
        children: [
          // 顶部：加载更早消息。
          if (state.hasMoreHistory ||
              state.isLoadingOlder ||
              state.historyError != null)
            AssistantHistoryControl(
              state: state,
              onLoadOlder: notifier.loadOlderMessages,
            ),
          // 中部：会话列表。
          Expanded(child: _buildConversationBody(state)),
          // 已有消息时的连接错误条；没有消息时错误由会话主体展示。
          if (state.messages.isNotEmpty && state.connectionError != null)
            AssistantConnectionStatus(
              state: state,
              onReconnect: notifier.reconnectActiveRun,
            ),
          // 底部：输入区。
          AssistantComposer(
            state: state,
            controller: _controller,
            sendBusy: _sendBusy,
            onPickAttachment: _pickAttachment,
            onSend: _send,
            onStop: notifier.stop,
            onRemoveAttachment: (mediaId) => ref
                .read(assistantNotifierProvider.notifier)
                .removePendingAttachment(mediaId),
          ),
        ],
      ),
    );
  }
}
