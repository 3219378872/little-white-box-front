import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../ads/presentation/ad_labels.dart';
import '../application/review_queue.dart';
import '../application/reviewer_access.dart';

/// 审核工作台首页：授权范围、各队列待处理数量与「领取下一单」（FX-111）。
class ReviewHomePage extends ConsumerStatefulWidget {
  const ReviewHomePage({super.key});

  @override
  ConsumerState<ReviewHomePage> createState() => _ReviewHomePageState();
}

class _ReviewHomePageState extends ConsumerState<ReviewHomePage> {
  bool _claiming = false;

  // 领取与授权/队列刷新由 ReviewQueueCommands 负责；页面只管忙碌态、导航与提示。
  Future<void> _claim([String purpose = '']) async {
    if (_claiming) return;
    setState(() => _claiming = true);
    final commands = ref.read(reviewQueueCommandsProvider);
    try {
      final task = await commands.claim(purpose: purpose);
      if (!mounted) return;
      if (task == null) {
        showAppSuccess(context, '队列暂无可领取的任务');
        return;
      }
      await context.push('/review/tasks/${jsonInt64Id(task.taskId)}');
      if (mounted) commands.refreshQueue();
    } catch (error) {
      if (!mounted) return;
      showAppError(context, '领取失败：${friendlyErrorMessage(error)}');
    } finally {
      if (mounted) setState(() => _claiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(reviewerAccessProvider);
    ref.watch(reviewQueueCommandsProvider);
    return FScaffold(
      header: FHeader.nested(
        title: const Text('审核工作台'),
        prefixes: [
          if (context.canPop())
            FHeaderAction.back(onPress: () => context.pop()),
        ],
        suffixes: [
          FHeaderAction(
            icon: const Icon(FLucideIcons.refreshCw),
            semanticsLabel: '刷新队列',
            onPress: () {
              ref.invalidate(reviewerAccessProvider);
              ref.invalidate(reviewQueueProvider);
            },
          ),
        ],
      ),
      child: access.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: friendlyErrorMessage(error),
          onRetry: () => ref.invalidate(reviewerAccessProvider),
        ),
        data: (access) =>
            access.canReview ? _content(access) : const ReviewForbiddenView(),
      ),
    );
  }

  Widget _content(ReviewerAccess access) {
    final theme = context.theme;
    final queue = ref.watch(reviewQueueProvider);
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pageInset),
      children: [
        AppSection(
          title: '我的授权',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppInfoRow.text(label: '角色', text: access.roles.join('、')),
              AppInfoRow.text(
                label: '市场',
                text: access.markets.map(adMarketLabel).join('、'),
              ),
              AppInfoRow.text(label: '语言', text: access.languages.join('、')),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.space4),
        FButton(
          key: const Key('review-claim-next'),
          prefix: const Icon(FLucideIcons.inbox),
          onPress: _claiming ? null : () => _claim(),
          child: Text(_claiming ? '领取中…' : '领取下一单'),
        ),
        const SizedBox(height: AppTheme.space4),
        Semantics(
          header: true,
          child: Text('待处理队列', style: theme.typography.body.lg),
        ),
        const SizedBox(height: AppTheme.space2),
        queue.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppTheme.space4),
            child: LoadingView(),
          ),
          error: (error, _) {
            if (error is ApiException &&
                error.code == ErrorCodes.reviewRoleRequired) {
              return const ReviewForbiddenView();
            }
            return ErrorView(
              message: friendlyErrorMessage(error),
              onRetry: () => ref.invalidate(reviewQueueProvider),
            );
          },
          data: (queue) => _buckets(queue),
        ),
      ],
    );
  }

  Widget _buckets(ReviewQueueResp queue) {
    final theme = context.theme;
    if (queue.buckets.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space4),
        child: Text(
          '授权范围内暂无待处理任务',
          style: theme.typography.body.sm.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FItemGroup(
          children: [
            for (final bucket in queue.buckets)
              FItem(
                key: Key('review-bucket-${bucket.purpose}'),
                prefix: const Icon(FLucideIcons.clipboardCheck),
                title: Text(reviewPurposeLabel(bucket.purpose)),
                subtitle: Text(
                  '待处理 ${bucket.pending} 单 · 最久等待 '
                  '${formatReviewAge(bucket.oldestAgeMs.toInt())}',
                ),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: _claiming || bucket.pending <= 0
                    ? null
                    : () => _claim(bucket.purpose),
              ),
          ],
        ),
        if (queue.policyVersion.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space2),
          Text(
            '政策版本 ${queue.policyVersion}',
            style: theme.typography.body.xs.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

/// 等待时长的紧凑文案。
String formatReviewAge(int ageMs) {
  if (ageMs <= 0) return '不足 1 分钟';
  final minutes = ageMs ~/ 60000;
  if (minutes < 1) return '不足 1 分钟';
  if (minutes < 60) return '$minutes 分钟';
  final hours = minutes ~/ 60;
  if (hours < 48) return '$hours 小时';
  return '${hours ~/ 24} 天';
}

/// 非审核员访问 `/review*` 时的无权限页（FX-112）。
class ReviewForbiddenView extends StatelessWidget {
  const ReviewForbiddenView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FLucideIcons.shieldCheck,
              size: 48,
              color: theme.colors.mutedForeground,
            ),
            const SizedBox(height: 16),
            Text('没有审核权限', style: theme.typography.body.lg),
            const SizedBox(height: 8),
            Text(
              '审核工作台只对已授权的审核人员开放。',
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
