import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../application/assistant_notifier.dart';
import '../application/watch_notifier.dart';
import '../data/assistant_models.dart';

class WatchPage extends ConsumerStatefulWidget {
  const WatchPage({super.key});

  @override
  ConsumerState<WatchPage> createState() => _WatchPageState();
}

class _WatchPageState extends ConsumerState<WatchPage> {
  BuildContext? _activeDialogContext;
  String? _activeDialogIdentity;
  bool _dialogDismissScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(agentConsentNotifierProvider.notifier).ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(assistantUserKeyProvider, (_, _) {
      _dismissDialogForIdentityChange();
    });
    final consent = ref.watch(agentConsentNotifierProvider);
    final tasks = ref.watch(watchListProvider);

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('追踪'),
        prefixes: [
          FHeaderAction.back(
            onPress: () => context.canPop()
                ? context.pop()
                : context.go('/messages/assistant'),
          ),
        ],
        suffixes: [
          if (consent.canUseMemoryWatch)
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus),
              semanticsLabel: '创建追踪',
              onPress: _create,
            ),
        ],
      ),
      child: Column(
        children: [
          if (consent.loaded && !consent.canUseMemoryWatch)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FAlert(
                title: Text(
                  consent.granted
                      ? '需要升级 Agent 授权才能管理追踪'
                      : '需要先授权 Agent 才能管理追踪',
                ),
                subtitle: const Text('命中会进入小白盒 Agent 线程，不会写入普通私信。未升级时仅可只读查看。'),
              ),
            ),
          if (tasks.error != null && tasks.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FAlert(
                key: const Key('watch-list-error'),
                variant: FAlertVariant.destructive,
                title: Text(tasks.error!),
                subtitle: Align(
                  alignment: Alignment.centerLeft,
                  child: FButton(
                    variant: .outline,
                    size: .sm,
                    onPress: () => ref.read(watchListProvider.notifier).load(),
                    child: const Text('重试'),
                  ),
                ),
              ),
            ),
          Expanded(
            child: tasks.loading && tasks.items.isEmpty
                ? const Center(child: FCircularProgress())
                : tasks.error != null && tasks.items.isEmpty
                ? ErrorView(
                    message: tasks.error!,
                    onRetry: () => ref.read(watchListProvider.notifier).load(),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Text('任务', style: context.theme.typography.body.md),
                      const SizedBox(height: 8),
                      if (tasks.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('还没有追踪任务'),
                        )
                      else
                        for (final task in tasks.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TaskTile(
                              task: task,
                              canWrite: consent.canUseMemoryWatch,
                              onToggle: () => _runWatchAction(
                                () => ref
                                    .read(watchListProvider.notifier)
                                    .setEnabled(task, !task.enabled),
                              ),
                              onDelete: () => _runWatchAction(
                                () => ref
                                    .read(watchListProvider.notifier)
                                    .deleteTask(task),
                              ),
                            ),
                          ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _runWatchAction(Future<void> Function() action) async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    try {
      await action();
    } catch (error) {
      if (mounted && _ownsIdentity(identity)) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _create() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    var condition = 'author_new_post';
    var target = '';
    var confirmed = false;
    try {
      await showFDialog<void>(
        context: context,
        builder: (dialogContext, style, animation) {
          _bindDialog(dialogContext, identity);
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('创建追踪', style: style.titleTextStyle),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final entry in watchConditionTargetTypes.entries)
                          FButton(
                            variant: condition == entry.key
                                ? .secondary
                                : .ghost,
                            size: .sm,
                            onPress: () =>
                                setDialogState(() => condition = entry.key),
                            child: Text(_conditionLabel(entry.key)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FTextField(
                      control: FTextFieldControl.lifted(
                        value: TextEditingValue(
                          text: target,
                          selection: TextSelection.collapsed(
                            offset: target.length,
                          ),
                        ),
                        onChange: (value) =>
                            setDialogState(() => target = value.text),
                      ),
                      label: Text(
                        condition == 'tag_new_post' ||
                                condition == 'keyword_new_post'
                            ? '标签或关键词'
                            : '目标 ID',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FButton(
                          variant: .outline,
                          onPress: () => Navigator.of(dialogContext).pop(),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        FButton(
                          onPress: () {
                            confirmed = true;
                            Navigator.of(dialogContext).pop();
                          },
                          child: const Text('创建'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
      if (!confirmed || !_ownsIdentity(identity)) return;
      final targetType = watchConditionTargetTypes[condition]!;
      final raw = target.trim();
      final notifier = ref.read(watchListProvider.notifier);
      try {
        await notifier.createTask(
          conditionType: condition,
          targetType: targetType,
          targetId:
              condition == 'author_new_post' || condition == 'post_revised'
              ? raw
              : 0,
          targetText:
              condition == 'tag_new_post' || condition == 'keyword_new_post'
              ? raw
              : '',
        );
      } catch (error) {
        if (mounted && _ownsIdentity(identity)) {
          showAppError(context, friendlyErrorMessage(error));
        }
      }
    } finally {
      _clearDialog(identity);
    }
  }

  bool _ownsIdentity(String identity) {
    return mounted &&
        identity.isNotEmpty &&
        ref.read(assistantUserKeyProvider) == identity;
  }

  void _bindDialog(BuildContext dialogContext, String identity) {
    _activeDialogContext = dialogContext;
    _activeDialogIdentity = identity;
    _dismissDialogForIdentityChange();
  }

  void _clearDialog(String identity) {
    if (_activeDialogIdentity != identity) return;
    _activeDialogContext = null;
    _activeDialogIdentity = null;
    _dialogDismissScheduled = false;
  }

  void _dismissDialogForIdentityChange() {
    final dialogContext = _activeDialogContext;
    final identity = _activeDialogIdentity;
    if (dialogContext == null ||
        identity == null ||
        _dialogDismissScheduled ||
        ref.read(assistantUserKeyProvider) == identity) {
      return;
    }
    _dialogDismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogDismissScheduled = false;
      if (!mounted ||
          _activeDialogContext != dialogContext ||
          _activeDialogIdentity != identity ||
          !dialogContext.mounted ||
          ref.read(assistantUserKeyProvider) == identity) {
        return;
      }
      Navigator.of(dialogContext).pop();
    });
  }
}

class _TaskTile extends StatelessWidget {
  final WatchTask task;
  final bool canWrite;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskTile({
    required this.task,
    required this.canWrite,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final target = jsonInt64IsPositive(task.targetId)
        ? jsonInt64Id(task.targetId)
        : task.targetText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.secondary,
        borderRadius: theme.style.borderRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conditionLabel(task.conditionType),
                    style: theme.typography.body.md,
                  ),
                  Text(
                    '${task.targetType}:$target · ${task.enabled ? '启用' : '停用'}',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            if (canWrite) ...[
              FButton(
                variant: .ghost,
                size: .sm,
                onPress: onToggle,
                child: Text(task.enabled ? '停用' : '启用'),
              ),
              FButton(
                variant: .ghost,
                size: .sm,
                onPress: onDelete,
                child: const Text('删除'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _conditionLabel(String type) {
  return switch (type) {
    'author_new_post' => '盯作者新帖',
    'tag_new_post' => '盯标签新帖',
    'keyword_new_post' => '盯关键词',
    'post_revised' => '盯帖子修订',
    _ => type,
  };
}
