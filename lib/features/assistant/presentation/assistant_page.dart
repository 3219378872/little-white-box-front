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
import '../application/assistant_notifier.dart';
import '../../post/data/post_repository.dart';
import '../data/assistant_models.dart';
import 'assistant_runtime_widgets.dart';

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

  /// 切换到 Agent 模式前先查询授权（FX-053/080）；未授权或版本偏低弹完整清单。
  Future<void> _switchMode(AssistantMode next) async {
    final notifier = ref.read(assistantNotifierProvider.notifier);
    if (next == AssistantMode.agent) {
      final consent = ref.read(agentConsentNotifierProvider.notifier);
      await consent.ensureLoaded();
      if (!mounted) return;
      final status = ref.read(agentConsentNotifierProvider);
      if (status.granted && !status.needsUpgrade) {
        notifier.setMode(next);
        return;
      }
      final agreed = await _showAgentConsentDialog(
        upgrade: status.needsUpgrade,
      );
      if (!mounted) return;
      if (!agreed) {
        if (status.granted) notifier.setMode(next);
        return;
      }
      try {
        await consent.grant();
      } on ApiException catch (error) {
        if (mounted) showAppError(context, friendlyErrorMessage(error));
        return;
      }
      notifier.setMode(next);
      return;
    }
    notifier.setMode(next);
  }

  /// FX-053/080：披露当前版本完整工具分组、记忆与 Watch。
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
              upgrade ? '升级 Agent 授权' : '启用 Agent 模式',
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

  Future<void> _runAction(AssistantStructuredAction action) async {
    try {
      switch (action.action) {
        case 'open_post':
          if (action.postId == null) return;
          context.push('/post/${jsonInt64Id(action.postId)}');
        case 'watch_author':
          final authorId = action.authorId ?? action.targetId;
          if (authorId == null) return;
          await ref
              .read(assistantRepositoryProvider)
              .createWatch(
                conditionType: 'author_new_post',
                targetType: 'author',
                targetId: authorId,
              );
          if (mounted) showAppSuccess(context, '已盯该作者');
        case 'watch_tag':
          final tag = action.targetText;
          if (tag.isEmpty) return;
          await ref
              .read(assistantRepositoryProvider)
              .createWatch(
                conditionType: 'tag_new_post',
                targetType: 'tag',
                targetText: tag,
              );
          if (mounted) showAppSuccess(context, '已盯该标签');
        case 'create_watch':
          final condition = action.conditionType;
          final targetType = action.targetType.isEmpty
              ? (watchConditionTargetTypes[condition] ?? '')
              : action.targetType;
          if (!watchConditionTargetTypes.containsKey(condition)) return;
          await ref
              .read(assistantRepositoryProvider)
              .createWatch(
                conditionType: condition,
                targetType: targetType,
                targetId: action.targetId ?? action.authorId ?? 0,
                targetText: action.targetText,
              );
          if (mounted) showAppSuccess(context, '已创建追踪');
        case 'dislike':
        case 'not_interested':
          if (action.postId == null) return;
          await ref
              .read(assistantRepositoryProvider)
              .submitRecommendFeedback(
                postId: action.postId!,
                reason: action.action == 'not_interested'
                    ? 'not_interested'
                    : 'dislike',
              );
          if (mounted) showAppSuccess(context, '已记录反馈');
        default:
          return;
      }
    } catch (error) {
      if (mounted) showAppError(context, friendlyErrorMessage(error));
    }
  }

  Future<void> _dislikeCard(AssistantStructuredCard card) async {
    if (!card.hasVerifiedPost) return;
    try {
      await ref
          .read(assistantRepositoryProvider)
          .submitRecommendFeedback(postId: card.postId!, reason: 'dislike');
      if (mounted) showAppSuccess(context, '已记录反馈');
    } catch (error) {
      if (mounted) showAppError(context, friendlyErrorMessage(error));
    }
  }

  Future<void> _pickAttachment() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxImageBytes) {
        if (mounted) showAppError(context, '图片不能超过 10 MiB');
        return;
      }
      final uploaded = await PostRepository().uploadImageMultipart(
        bytes: bytes,
        filename: file.name,
      );
      if (!mounted) return;
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
      if (mounted) {
        showAppError(context, '图片上传失败: ${friendlyErrorMessage(error)}');
      }
    }
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
    final consent = ref.watch(agentConsentNotifierProvider);
    ref.listen<AssistantState>(assistantNotifierProvider, (previous, next) {
      // FX-054：AGENT_NOT_AUTHORIZED 错误重新触发授权流程。
      if (!previous!.agentAuthorizationRequired &&
          next.agentAuthorizationRequired) {
        _switchMode(AssistantMode.enhancedSearch);
        _showAgentConsentDialog().then((agreed) {
          if (agreed && mounted) {
            ref
                .read(assistantNotifierProvider.notifier)
                .setMode(AssistantMode.agent);
          }
        });
      }
      if (next.messages.isNotEmpty) _scheduleScroll();
    });

    return FScaffold(
      childPad: false,
      header: FHeader(
        title: const Text('Assistant'),
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.brain),
            semanticsLabel: '记忆',
            onPress: () => context.push('/assistant/memory'),
          ),
          FHeaderAction(
            icon: const Icon(FLucideIcons.bell),
            semanticsLabel: '追踪',
            onPress: () => context.push('/assistant/watch'),
          ),
          if (state.messages.isNotEmpty)
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
                      onConfirm: (callId, approved) => ref
                          .read(assistantNotifierProvider.notifier)
                          .respondToConfirmation(callId, approved),
                      onAction: _runAction,
                      onDislikeCard: _dislikeCard,
                      onOpenHit: (hit) {
                        if (!hit.hasVerifiedPost) return;
                        context.push('/post/${jsonInt64Id(hit.postId)}');
                      },
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
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      _ModeChip(
                        key: const Key('assistant-mode-enhanced'),
                        label: '增强搜索',
                        icon: FLucideIcons.search,
                        active: state.mode == AssistantMode.enhancedSearch,
                        onPress: () =>
                            _switchMode(AssistantMode.enhancedSearch),
                      ),
                      const SizedBox(width: 8),
                      _ModeChip(
                        key: const Key('assistant-mode-agent'),
                        label: 'Agent',
                        icon: FLucideIcons.bot,
                        active: state.mode == AssistantMode.agent,
                        onPress: () => _switchMode(AssistantMode.agent),
                      ),
                      const Spacer(),
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
                  if (state.mode == AssistantMode.agent &&
                      state.pendingAttachments.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _PendingAttachmentRow(state: state),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (state.mode == AssistantMode.agent) ...[
                        FButton.icon(
                          key: const Key('assistant-add-attachment'),
                          variant: .ghost,
                          onPress: state.isStreaming ? null : _pickAttachment,
                          child: const Icon(
                            FLucideIcons.imagePlus,
                            semanticLabel: '添加图片附件',
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: FTextField.multiline(
                          control: FTextFieldControl.managed(
                            controller: _controller,
                          ),
                          label: const Text('消息'),
                          hint: state.mode == AssistantMode.agent
                              ? '描述任务，例如“把这张图发成一个帖子”'
                              : '输入消息',
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
                            ? ref
                                  .read(assistantNotifierProvider.notifier)
                                  .cancel
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onPress;

  const _ModeChip({
    super.key,
    required this.label,
    required this.icon,
    required this.active,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    return FButton(
      variant: active ? .secondary : .ghost,
      size: .sm,
      onPress: onPress,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14), const SizedBox(width: 6), Text(label)],
      ),
    );
  }
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
    AssistantToolStatus.completed => '完成',
    AssistantToolStatus.confirmed => '已确认',
    AssistantToolStatus.declined => '已拒绝',
    AssistantToolStatus.expired => '已超时取消',
    AssistantToolStatus.failed => '失败',
  };
}

class _AssistantMessageBubble extends StatelessWidget {
  final AssistantMessage message;
  final bool Function(AssistantSourceReference) canOpenSource;
  final ValueChanged<AssistantSourceReference> onOpenSource;
  final void Function(String callId, bool approved)? onConfirm;
  final ValueChanged<AssistantStructuredAction>? onAction;
  final ValueChanged<AssistantStructuredCard>? onDislikeCard;
  final ValueChanged<AssistantWatchHitNotice>? onOpenHit;

  const _AssistantMessageBubble({
    required this.message,
    required this.canOpenSource,
    required this.onOpenSource,
    this.onConfirm,
    this.onAction,
    this.onDislikeCard,
    this.onOpenHit,
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
                    for (final step in message.toolSteps)
                      _ToolStepEntry(step: step, onConfirm: onConfirm),
                    if (bodyText.isNotEmpty || message.isStreaming)
                      const SizedBox(height: 8),
                  ],
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    source.sourceType == 'web'
                                        ? FLucideIcons.globe
                                        : FLucideIcons.fileQuestion,
                                    size: 12,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    source.title.isEmpty
                                        ? '${source.sourceType}:${source.sourceId}'
                                        : source.title,
                                  ),
                                ],
                              ),
                            ),
                      ],
                    ),
                  ],
                  AssistantCardsAndActions(
                    message: message,
                    onAction: onAction ?? (_) {},
                    onDislike: onDislikeCard ?? (_) {},
                    onOpenHit: onOpenHit ?? (_) {},
                  ),
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

/// 工具进度行与确认卡片（FX-056~058）。
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
