part of 'assistant_page.dart';

extension _AssistantPageControls on _AssistantPageState {
  FHeader _buildAssistantHeader(
    AssistantState state,
    AgentConsentState consent,
  ) {
    final theme = context.theme;
    final busy = state.isQueued || state.hasActiveRun || state.isStreaming;
    return FHeader.nested(
      // Run status lives under the title instead of floating over the composer.
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
      prefixes: [
        FHeaderAction.back(
          onPress: () =>
              context.canPop() ? context.pop() : context.go('/messages'),
        ),
      ],
      suffixes: [
        FTooltip(
          tipBuilder: (_, _) => const Text('记忆'),
          child: FHeaderAction(
            icon: const Icon(FLucideIcons.notebookText),
            semanticsLabel: '记忆',
            onPress: () => context.push('/messages/assistant/memory'),
          ),
        ),
        FTooltip(
          tipBuilder: (_, _) => const Text('追踪'),
          child: FHeaderAction(
            icon: const Icon(FLucideIcons.bell),
            semanticsLabel: '追踪',
            onPress: () => context.push('/messages/assistant/watch'),
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
                          ref
                              .read(assistantNotifierProvider.notifier)
                              .clearHistory();
                        },
                ),
                if (consent.loaded && consent.granted)
                  FItem(
                    key: const Key('assistant-revoke-consent'),
                    prefix: const Icon(FLucideIcons.shieldOff),
                    title: const Text('撤销 Agent 授权'),
                    onPress: () {
                      controller.hide();
                      _revokeAuthorization();
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

  Widget _buildComposer(AssistantState state, AgentConsentState consent) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                  child: Semantics(
                    label: '消息',
                    child: FTextField.multiline(
                      control: FTextFieldControl.managed(
                        controller: _controller,
                      ),
                      hint: '输入消息',
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 2000,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Stop only while the Agent is producing output; a run that
                // waits for the user's answer has nothing to stop.
                if ((state.hasActiveRun || state.isStreaming) &&
                    state.activeRunPhase != 'waiting_input') ...[
                  FTooltip(
                    tipBuilder: (_, _) => const Text('停止生成'),
                    child: FButton.icon(
                      key: const Key('assistant-stop'),
                      variant: FButtonVariant.secondary,
                      onPress: ref
                          .read(assistantNotifierProvider.notifier)
                          .stop,
                      child: const Icon(
                        FLucideIcons.circleStop,
                        semanticLabel: '停止生成',
                      ),
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
                  child: const Icon(FLucideIcons.send, semanticLabel: '发送'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryControl(AssistantState state) {
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
    );
  }

  Widget _buildConnectionStatus(AssistantState state) {
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
                  onPress: ref
                      .read(assistantNotifierProvider.notifier)
                      .reconnectActiveRun,
                  child: const Text('重新连接'),
                ),
              )
            : null,
      ),
    );
  }
}
