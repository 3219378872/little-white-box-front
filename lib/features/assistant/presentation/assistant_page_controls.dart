import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../application/agent_consent_notifier.dart';
import '../application/assistant_state.dart';
import '../data/assistant_models.dart';

// 页面外围控件只依赖传入的状态与回调，不读取 provider，也不触碰页面 State 的私有成员。

/// Agent 页头：标题下展示运行状态，右侧提供记忆入口与清除历史、撤销授权菜单。
class AssistantPageHeader extends StatelessWidget {
  final AssistantState state;
  final AgentConsentState consent;
  final VoidCallback onClearHistory;
  final VoidCallback onRevokeConsent;

  const AssistantPageHeader({
    super.key,
    required this.state,
    required this.consent,
    required this.onClearHistory,
    required this.onRevokeConsent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final busy = state.isQueued || state.hasActiveRun || state.isStreaming;
    return FHeader.nested(
      // 运行状态放在标题下方，而不是浮在输入框上。
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '小白盒 Agent',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.md.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (busy)
            Semantics(
              liveRegion: true,
              child: Text(
                _busyLabel(state),
                key: const Key('assistant-run-status'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.xs.copyWith(
                  color: state.activeRunPhase == 'waiting_input'
                      ? theme.colors.primary
                      : theme.colors.mutedForeground,
                ),
              ),
            ),
        ],
      ),
      // 左侧：返回；无可返回页面时回到消息列表。
      prefixes: [
        FHeaderAction.back(
          onPress: () =>
              context.canPop() ? context.pop() : context.go(AppRoutes.messages),
        ),
      ],
      // 右侧：记忆入口与更多菜单（授权状态、清除历史、撤销授权）。
      suffixes: [
        FTooltip(
          tipBuilder: (_, _) => const Text('记忆'),
          child: FHeaderAction(
            icon: const Icon(FLucideIcons.notebookText),
            semanticsLabel: '记忆',
            onPress: () => context.push(AppRoutes.assistantMemory),
          ),
        ),
        FPopoverMenu(
          menuAnchor: Alignment.topRight,
          childAnchor: Alignment.bottomRight,
          menuBuilder: (context, controller, _) => [
            if (consent.loaded && consent.granted)
              FItemGroup(
                children: [
                  FItem(
                    key: const Key('assistant-consent-status'),
                    prefix: const Icon(FLucideIcons.shieldCheck),
                    title: Text(
                      consent.needsUpgrade
                          ? '授权待升级 v${consent.consentVersion}'
                          : 'Agent 已授权 v${consent.consentVersion}',
                    ),
                    onPress: null,
                  ),
                ],
              ),
            FItemGroup(
              children: [
                FItem(
                  key: const Key('assistant-clear-history'),
                  prefix: const Icon(FLucideIcons.trash2),
                  title: const Text('清除历史'),
                  onPress:
                      !state.isLoaded ||
                          state.isLoadingHistory ||
                          state.isSending
                      ? null
                      : () {
                          controller.hide();
                          onClearHistory();
                        },
                ),
                if (consent.loaded && consent.granted)
                  FItem(
                    key: const Key('assistant-revoke-consent'),
                    prefix: const Icon(FLucideIcons.shieldOff),
                    title: const Text('撤销 Agent 授权'),
                    onPress: () {
                      controller.hide();
                      onRevokeConsent();
                    },
                  ),
              ],
            ),
          ],
          builder: (context, controller, _) => FHeaderAction(
            key: const Key('assistant-menu'),
            icon: const Icon(FLucideIcons.ellipsis),
            semanticsLabel: '更多操作',
            onPress: controller.toggle,
          ),
        ),
      ],
    );
  }
}

/// Agent 输入区：待发送图片、附件按钮、多行输入框与发送按钮；运行中额外出现停止按钮。
class AssistantComposer extends StatelessWidget {
  final AssistantState state;
  final TextEditingController controller;

  /// 页面正在执行发送流程（含授权弹窗）时为 true，期间禁用发送与添加附件。
  final bool sendBusy;
  final VoidCallback onPickAttachment;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final ValueChanged<Object> onRemoveAttachment;

  const AssistantComposer({
    super.key,
    required this.state,
    required this.controller,
    required this.sendBusy,
    required this.onPickAttachment,
    required this.onSend,
    required this.onStop,
    required this.onRemoveAttachment,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 待发送图片。
            if (state.pendingAttachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              _PendingAttachmentRow(
                attachments: state.pendingAttachments,
                onRemove: onRemoveAttachment,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 输入行：添加附件、输入框、停止（仅运行中）与发送。
                FButton.icon(
                  key: const Key('assistant-add-attachment'),
                  variant: .ghost,
                  onPress:
                      state.isLoaded &&
                          !state.isLoadingHistory &&
                          !state.isSending &&
                          !sendBusy
                      ? onPickAttachment
                      : null,
                  child: const Icon(
                    FLucideIcons.imagePlus,
                    semanticLabel: '添加图片附件',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Semantics(
                    label: '消息',
                    child: FTextField.multiline(
                      control: FTextFieldControl.managed(
                        controller: controller,
                      ),
                      hint: '输入消息',
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // 只在 Agent 产出内容时允许停止；等待用户回答的运行没有可停止的输出。
                if ((state.hasActiveRun || state.isStreaming) &&
                    state.activeRunPhase != 'waiting_input') ...[
                  FTooltip(
                    tipBuilder: (_, _) => const Text('停止生成'),
                    child: FButton.icon(
                      key: const Key('assistant-stop'),
                      variant: FButtonVariant.secondary,
                      onPress: onStop,
                      child: const Icon(
                        FLucideIcons.circleStop,
                        semanticLabel: '停止生成',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 发送在请求在途、历史加载中或页面发送流程未结束时禁用。
                FButton.icon(
                  key: const Key('assistant-send-or-stop'),
                  variant: FButtonVariant.primary,
                  onPress:
                      state.isLoaded &&
                          !state.isLoadingHistory &&
                          state.canSend &&
                          !sendBusy
                      ? onSend
                      : null,
                  child: const Icon(FLucideIcons.send, semanticLabel: '发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 会话顶部的「加载更早消息」入口；历史加载失败时在按钮下方显示错误。
class AssistantHistoryControl extends StatelessWidget {
  final AssistantState state;
  final VoidCallback onLoadOlder;

  const AssistantHistoryControl({
    super.key,
    required this.state,
    required this.onLoadOlder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Column(
        children: [
          FButton(
            key: const Key('assistant-load-older'),
            variant: .ghost,
            size: .sm,
            onPress: state.isLoadingHistory || state.isLoadingOlder
                ? null
                : onLoadOlder,
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
    );
  }
}

/// 已有消息时的连接错误条；仍有活动运行但流已断开时提供「重新连接」。
class AssistantConnectionStatus extends StatelessWidget {
  final AssistantState state;
  final VoidCallback onReconnect;

  const AssistantConnectionStatus({
    super.key,
    required this.state,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
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
                  onPress: onReconnect,
                  child: const Text('重新连接'),
                ),
              )
            : null,
      ),
    );
  }
}

// 页头运行状态文案：等待回答优先，其次排队，再按最近一次投递结果与当前阶段区分。
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

// 已上传、待随下一条消息发送的图片缩略图，每张右上角可移除。
class _PendingAttachmentRow extends StatelessWidget {
  final List<PendingChatImage> attachments;
  final ValueChanged<Object> onRemove;

  const _PendingAttachmentRow({
    required this.attachments,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in attachments)
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
                  onPress: () => onRemove(image.mediaId),
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
