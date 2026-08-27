import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../application/assistant_notifier.dart';
import '../application/memory_notifier.dart';
import '../data/assistant_models.dart';

class MemoryPage extends ConsumerStatefulWidget {
  const MemoryPage({super.key});

  @override
  ConsumerState<MemoryPage> createState() => _MemoryPageState();
}

class _MemoryPageState extends ConsumerState<MemoryPage> {
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
    final consent = ref.watch(agentConsentNotifierProvider);
    final state = ref.watch(memoryListProvider);
    final theme = context.theme;

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('记忆'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/assistant'),
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
                      ? '需要升级 Agent 授权才能修改记忆'
                      : '需要先授权 Agent 才能管理记忆',
                ),
                subtitle: Text(
                  consent.granted
                      ? '当前授权版本 ${consent.consentVersion}，披露版本 ${consent.currentVersion}。仍可只读查看。'
                      : '可只读查看已有记忆；写入需在 Assistant 完成授权。',
                ),
              ),
            ),
          Expanded(
            child: state.loading && state.items.isEmpty
                ? const Center(child: FCircularProgress())
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
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: state.items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = state.items[index];
                      return _MemoryTile(
                        record: item,
                        canWrite: consent.canUseMemoryWatch,
                        onEdit: () => _edit(item),
                        onSuppress: () => _suppress(item),
                        onDelete: () => _delete(item),
                      );
                    },
                  ),
          ),
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

  Future<void> _edit(MemoryRecord record) async {
    final valueCtrl = TextEditingController(text: record.value);
    final scoreCtrl = TextEditingController(text: record.score.toString());
    var confirmed = false;
    try {
      await showFDialog<void>(
        context: context,
        builder: (dialogContext, style, animation) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('修改记忆', style: style.titleTextStyle),
              const SizedBox(height: 12),
              FTextField(
                control: FTextFieldControl.managed(controller: valueCtrl),
                label: const Text('值'),
              ),
              const SizedBox(height: 8),
              FTextField(
                control: FTextFieldControl.managed(controller: scoreCtrl),
                label: const Text('分值'),
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
      if (!confirmed || !mounted) return;
      final score = double.tryParse(scoreCtrl.text.trim());
      if (score == null) {
        showAppError(context, '分值无效');
        return;
      }
      try {
        await ref
            .read(memoryListProvider.notifier)
            .updateRecord(
              record: record,
              value: valueCtrl.text.trim(),
              score: score,
            );
      } catch (error) {
        if (mounted) {
          showAppError(context, friendlyErrorMessage(error));
        }
      }
    } finally {
      valueCtrl.dispose();
      scoreCtrl.dispose();
    }
  }

  Future<void> _suppress(MemoryRecord record) async {
    try {
      await ref
          .read(memoryListProvider.notifier)
          .updateRecord(record: record, suppressed: true);
    } catch (error) {
      if (mounted) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }

  Future<void> _delete(MemoryRecord record) async {
    try {
      await ref.read(memoryListProvider.notifier).deleteRecord(record);
    } catch (error) {
      if (mounted) {
        showAppError(context, friendlyErrorMessage(error));
      }
    }
  }
}

class _MemoryTile extends StatelessWidget {
  final MemoryRecord record;
  final bool canWrite;
  final VoidCallback onEdit;
  final VoidCallback onSuppress;
  final VoidCallback onDelete;

  const _MemoryTile({
    required this.record,
    required this.canWrite,
    required this.onEdit,
    required this.onSuppress,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.secondary,
        borderRadius: theme.style.borderRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FBadge(variant: .secondary, child: Text(record.layer)),
                const SizedBox(width: 8),
                Text(record.dimension, style: theme.typography.body.sm),
                const Spacer(),
                Text(
                  record.confirmed ? '已确认' : '可能的偏好',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(record.value, style: theme.typography.body.md),
            const SizedBox(height: 4),
            Text(
              '分值 ${record.score.toStringAsFixed(2)} · ${record.source}'
              '${record.suppressed ? ' · 已禁止记住' : ''}',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            if (canWrite) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  FButton(
                    variant: .ghost,
                    size: .sm,
                    onPress: onEdit,
                    child: const Text('修改'),
                  ),
                  FButton(
                    variant: .ghost,
                    size: .sm,
                    onPress: onSuppress,
                    child: const Text('不要记住这个'),
                  ),
                  FButton(
                    variant: .ghost,
                    size: .sm,
                    onPress: onDelete,
                    child: const Text('删除'),
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
