import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/assistant_notifier.dart';
import '../application/memory_notifier.dart';
import '../data/assistant_models.dart';
import '../../../core/router/app_routes.dart';

/// 记忆管理页：查看各分区记忆与容量；授权有效时可新增、修改、删除并撤销最近一次
/// 变更，否则只读。
class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

// 记录当前打开的弹窗及其所属身份，账号切换时关闭弹窗，避免把输入写进新账号。
class _MemoryPageState extends ConsumerState<MemoryPage> {
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
    // 登录身份变化时关闭旧账号打开的弹窗。
    ref.listen<String>(assistantUserKeyProvider, (_, _) {
      _dismissDialogForIdentityChange();
    });
    final consent = ref.watch(agentConsentNotifierProvider);
    final state = ref.watch(memoryListProvider);
    final theme = context.theme;

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('记忆'),
        prefixes: [
          FHeaderAction.back(
            onPress: () => context.canPop()
                ? context.pop()
                : context.go(AppRoutes.assistant),
          ),
        ],
        // 授权有效时才提供新增与撤销入口。
        suffixes: [
          if (consent.canUseMemory)
            FHeaderAction(
              icon: const Icon(FLucideIcons.plus),
              semanticsLabel: '新增记忆',
              onPress: _add,
            ),
          if (consent.canUseMemory && state.lastChangeId != null)
            FHeaderAction(
              icon: const Icon(FLucideIcons.rotateCcw),
              semanticsLabel: '撤销',
              onPress: _undo,
            ),
        ],
      ),
      child: Column(
        children: [
          // 只读提示：未授权或授权待升级。
          if (consent.loaded && !consent.canUseMemory)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: FAlert(
                title: Text(
                  consent.granted
                      ? '需要升级 Agent 授权才能修改记忆'
                      : '需要先授权 Agent 才能管理记忆',
                ),
                subtitle: Text(
                  consent.granted
                      ? '当前授权版本 ${consent.consentVersion}，披露版本 ${consent.currentVersion}。仍可只读查看。'
                      : '可只读查看已有记忆；写入需在小白盒 Agent 完成授权。',
                ),
              ),
            ),
          // 各分区容量。
          if (state.capacities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final cap in state.capacities)
                    AppBadge(
                      variant: .secondary,
                      child: Text('${cap.target} ${cap.used}/${cap.limit}'),
                    ),
                ],
              ),
            ),
          // 列表区：加载、错误、空态或记忆条目。
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const LoadingView()
                : state.error != null && state.items.isEmpty
                ? ErrorView(
                    message: state.error!,
                    onRetry: ref.read(memoryListProvider.notifier).load,
                  )
                : state.items.isEmpty
                ? const EmptyView(
                    message: '还没有可展示的记忆',
                    icon: FLucideIcons.brain,
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const FDivider(),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _MemoryTile(
                        record: item,
                        canWrite: consent.canUseMemory,
                        onEdit: () => _edit(item),
                        onDelete: () => _delete(item),
                      );
                    },
                  ),
          ),
          // 已有条目时的错误显示在底部，不替换列表。
          if (state.error != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                state.error!,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.destructive,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 新增记忆弹窗：选择分区并填写内容，确认后写入。
  Future<void> _add() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    var target = 'memory';
    var content = '';
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
                    Text('新增记忆', style: style.titleTextStyle),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        FButton(
                          variant: target == 'memory' ? .secondary : .ghost,
                          size: .sm,
                          onPress: () =>
                              setDialogState(() => target = 'memory'),
                          child: const Text('MEMORY'),
                        ),
                        const SizedBox(width: 8),
                        FButton(
                          variant: target == 'user' ? .secondary : .ghost,
                          size: .sm,
                          onPress: () => setDialogState(() => target = 'user'),
                          child: const Text('USER'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FTextField.multiline(
                      control: FTextFieldControl.lifted(
                        value: TextEditingValue(
                          text: content,
                          selection: TextSelection.collapsed(
                            offset: content.length,
                          ),
                        ),
                        onChange: (value) =>
                            setDialogState(() => content = value.text),
                      ),
                      label: const Text('内容'),
                      minLines: 2,
                      maxLines: 6,
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
                          child: const Text('保存'),
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
      final notifier = ref.read(memoryListProvider.notifier);
      try {
        await notifier.addRecord(target: target, content: content.trim());
      } catch (error) {
        if (mounted && _ownsIdentity(identity)) {
          showAppError(context, friendlyErrorMessage(error));
        }
      }
    } finally {
      _clearDialog(identity);
    }
  }

  // 修改记忆弹窗，确认后按读取时的版本替换。
  Future<void> _edit(MemoryRecord record) async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    var content = record.content;
    var confirmed = false;
    try {
      await showFDialog<void>(
        context: context,
        builder: (dialogContext, style, animation) {
          _bindDialog(dialogContext, identity);
          return StatefulBuilder(
            builder: (context, setDialogState) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('修改记忆', style: style.titleTextStyle),
                  const SizedBox(height: 12),
                  FTextField.multiline(
                    control: FTextFieldControl.lifted(
                      value: TextEditingValue(
                        text: content,
                        selection: TextSelection.collapsed(
                          offset: content.length,
                        ),
                      ),
                      onChange: (value) =>
                          setDialogState(() => content = value.text),
                    ),
                    label: const Text('内容'),
                    minLines: 2,
                    maxLines: 6,
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
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (!confirmed || !_ownsIdentity(identity)) return;
      final notifier = ref.read(memoryListProvider.notifier);
      try {
        await notifier.updateRecord(record: record, content: content.trim());
      } catch (error) {
        if (mounted && _ownsIdentity(identity)) {
          showAppError(context, friendlyErrorMessage(error));
        }
      }
    } finally {
      _clearDialog(identity);
    }
  }

  // 删除记忆（携带版本），之后可经撤销恢复。
  Future<void> _delete(MemoryRecord record) async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    final notifier = ref.read(memoryListProvider.notifier);
    try {
      await notifier.deleteRecord(record);
    } catch (error) {
      if (mounted && _ownsIdentity(identity)) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  // 撤销最近一次写入。
  Future<void> _undo() async {
    final identity = ref.read(assistantUserKeyProvider);
    if (!_ownsIdentity(identity)) return;
    final notifier = ref.read(memoryListProvider.notifier);
    try {
      await notifier.undoLastChange();
    } catch (error) {
      if (mounted && _ownsIdentity(identity)) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  // 异步操作返回后确认页面仍挂载且登录身份未变。
  bool _ownsIdentity(String identity) {
    return mounted &&
        identity.isNotEmpty &&
        ref.read(assistantUserKeyProvider) == identity;
  }

  // 登记当前弹窗；登记时身份已变化则立即安排关闭。
  void _bindDialog(BuildContext dialogContext, String identity) {
    _activeDialogContext = dialogContext;
    _activeDialogIdentity = identity;
    _dismissDialogForIdentityChange();
  }

  // 弹窗结束后注销登记（只注销同一身份的登记）。
  void _clearDialog(String identity) {
    if (_activeDialogIdentity != identity) return;
    _activeDialogContext = null;
    _activeDialogIdentity = null;
    _dialogDismissScheduled = false;
  }

  // 身份已切换时在下一帧关闭仍打开的弹窗；同一时间只安排一次。
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

// 单条记忆：分区标签、版本号与内容；可写时提供修改与删除。
class _MemoryTile extends StatelessWidget {
  final MemoryRecord record;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemoryTile({
    required this.record,
    required this.canWrite,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(color: theme.colors.background),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppBadge(
                  variant: .secondary,
                  child: Text(record.target.toUpperCase()),
                ),
                const Spacer(),
                Text(
                  'v${record.version}',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(record.content, style: theme.typography.body.md),
            if (canWrite) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  AppIconButton(
                    icon: FLucideIcons.pencil,
                    label: '修改',
                    onPress: onEdit,
                  ),
                  AppIconButton(
                    icon: FLucideIcons.trash2,
                    label: '删除',
                    onPress: onDelete,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
