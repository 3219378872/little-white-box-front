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
    final tasks = ref.watch(watchListProvider);
    final hits = ref.watch(watchHitsProvider);
    final empty = tasks.items.isEmpty && hits.items.isEmpty;
    final loading = (tasks.loading || hits.loading) && empty;
    final error = tasks.error ?? hits.error;

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('追踪'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/assistant'),
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
                subtitle: const Text('命中仍只出现在助手内，不会写入私信。未升级时仅可只读查看。'),
              ),
            ),
          Expanded(
            child: loading
                ? const Center(child: FCircularProgress())
                : error != null && empty
                ? ErrorView(message: error, onRetry: _reload)
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
                      const SizedBox(height: 16),
                      Text('命中收件箱', style: context.theme.typography.body.md),
                      const SizedBox(height: 8),
                      if (hits.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('还没有追踪命中'),
                        )
                      else
                        for (final hit in hits.items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HitTile(
                              hit: hit,
                              onOpen: hit.hasVerifiedPost
                                  ? () {
                                      context.push(
                                        '/post/${jsonInt64Id(hit.postId)}',
                                      );
                                      if (!hit.read) {
                                        _runWatchAction(
                                          () => ref
                                              .read(watchHitsProvider.notifier)
                                              .markHitRead(hit),
                                        );
                                      }
                                    }
                                  : null,
                              onMarkRead: hit.read
                                  ? null
                                  : () => _runWatchAction(
                                      () => ref
                                          .read(watchHitsProvider.notifier)
                                          .markHitRead(hit),
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

  void _reload() {
    ref.read(watchListProvider.notifier).load();
    ref.read(watchHitsProvider.notifier).load();
  }

  Future<void> _runWatchAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      showAppError(context, friendlyErrorMessage(error));
    }
  }

  Future<void> _create() async {
    var condition = 'author_new_post';
    final targetCtrl = TextEditingController();
    var confirmed = false;
    try {
      await showFDialog<void>(
        context: context,
        builder: (dialogContext, style, animation) {
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
                      control: FTextFieldControl.managed(
                        controller: targetCtrl,
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
      if (!confirmed || !mounted) return;
      final targetType = watchConditionTargetTypes[condition]!;
      final raw = targetCtrl.text.trim();
      try {
        await ref
            .read(watchListProvider.notifier)
            .createTask(
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
        if (mounted) {
          showAppError(context, friendlyErrorMessage(error));
        }
      }
    } finally {
      targetCtrl.dispose();
    }
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

class _HitTile extends StatelessWidget {
  final WatchHit hit;
  final VoidCallback? onOpen;
  final VoidCallback? onMarkRead;

  const _HitTile({required this.hit, this.onOpen, this.onMarkRead});

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
        child: Row(
          children: [
            Expanded(
              child: FTappable(
                onPress: onOpen,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hit.title.isEmpty ? '已发布帖子' : hit.title,
                      style: theme.typography.body.md,
                    ),
                    Text(
                      hit.read ? '已读' : '未读',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onMarkRead != null)
              FButton(
                variant: .ghost,
                size: .sm,
                onPress: onMarkRead,
                child: const Text('标为已读'),
              ),
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
