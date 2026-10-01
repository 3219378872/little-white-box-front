import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../ads/application/ads_providers.dart';
import '../../ads/data/ad_labels.dart';
import '../application/review_task_controller.dart';
import '../application/reviewer_access.dart';
import 'review_decision_form.dart';
import 'review_evidence.dart';
import 'review_home_page.dart';

/// 剩余持有时间低于该值时提示续期（FX-111）。
const reviewLeaseWarning = Duration(minutes: 2);

/// 审核任务详情：快照、机审证据、政策定义与结论表单，单列布局（FX-111、FX-113）。
class ReviewTaskPage extends ConsumerStatefulWidget {
  final String taskId;
  final DateTime Function() now;

  const ReviewTaskPage({
    super.key,
    required this.taskId,
    this.now = DateTime.now,
  });

  @override
  ConsumerState<ReviewTaskPage> createState() => _ReviewTaskPageState();
}

class _ReviewTaskPageState extends ConsumerState<ReviewTaskPage> {
  Timer? _ticker;
  num? _warnedLeaseUntil;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeWarnLease();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  ReviewTaskController get _controller =>
      ref.read(reviewTaskControllerProvider(widget.taskId).notifier);

  Duration _remaining(ReviewTaskItem task) {
    final ms = task.leaseUntilMs.toInt() - widget.now().millisecondsSinceEpoch;
    return Duration(milliseconds: ms < 0 ? 0 : ms);
  }

  void _maybeWarnLease() {
    final state = ref.read(reviewTaskControllerProvider(widget.taskId));
    final task = state.task;
    if (task == null || !state.editable) return;
    final remaining = _remaining(task);
    if (remaining > reviewLeaseWarning ||
        _warnedLeaseUntil == task.leaseUntilMs) {
      return;
    }
    _warnedLeaseUntil = task.leaseUntilMs;
    showAppError(context, '持有剩余不足 2 分钟，请续期或尽快提交');
  }

  Future<void> _renew() async {
    if (await _controller.renew() && mounted) showAppSuccess(context, '已续期');
  }

  Future<void> _release() async {
    if (await _controller.release() && mounted) context.go('/review');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewTaskControllerProvider(widget.taskId));
    final access = ref.watch(reviewerAccessProvider);
    final forbidden =
        access.hasValue && !access.value!.canReview ||
        state.closure == ReviewTaskClosure.forbidden;
    return FScaffold(
      header: FHeader.nested(
        title: const Text('审核任务'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/review'),
          ),
        ],
      ),
      child: forbidden ? const ReviewForbiddenView() : _body(state),
    );
  }

  Widget _body(ReviewTaskState state) {
    final task = state.task;
    if (state.loading && task == null) {
      return const Center(child: FCircularProgress());
    }
    if (task == null) {
      return state.closure != null
          ? _closed(state.closure!)
          : ErrorView(
              message: state.error ?? '任务加载失败',
              onRetry: _controller.load,
            );
    }
    final policies =
        ref.watch(adPolicyCatalogProvider).value ?? AdPolicyCatalog.fallback;
    return ListView(
      padding: const EdgeInsets.all(AppTheme.pageInset),
      children: [
        _summary(task, state),
        if (state.closure != null) ...[
          const SizedBox(height: AppTheme.space3),
          _closureAlert(state.closure!),
        ],
        if (state.decision != null) ...[
          const SizedBox(height: AppTheme.space3),
          FAlert(
            icon: const Icon(FLucideIcons.circleCheck),
            title: const Text('结论已提交'),
            subtitle: Text(
              '${reviewVerdictLabel(state.decision!.verdict)}'
              '${state.decision!.policyCodes.isEmpty ? '' : '：${state.decision!.policyCodes.map(policies.titleOf).join('、')}'}',
            ),
          ),
        ],
        if (state.error != null) ...[
          const SizedBox(height: AppTheme.space3),
          FAlert(
            variant: FAlertVariant.destructive,
            icon: const Icon(FLucideIcons.circleAlert),
            title: Text(state.error!),
          ),
        ],
        const SizedBox(height: AppTheme.space3),
        if (task.originalDecision != null) ...[
          OriginalDecisionSection(
            purpose: task.purpose,
            decision: task.originalDecision!,
            policies: policies,
          ),
          const SizedBox(height: AppTheme.space3),
        ],
        ReviewEvidence(task: task),
        const SizedBox(height: AppTheme.space3),
        if (state.editable)
          ReviewDecisionForm(
            policies: policies,
            busy: state.busy,
            onSubmit: _controller.submit,
          )
        else if (state.closure != null || state.decision != null)
          FButton(
            variant: FButtonVariant.outline,
            onPress: () => context.go('/review'),
            child: const Text('返回队列'),
          ),
        const SizedBox(height: AppTheme.space6),
      ],
    );
  }

  Widget _summary(ReviewTaskItem task, ReviewTaskState state) {
    final theme = context.theme;
    final remaining = _remaining(task);
    final expiring = remaining <= reviewLeaseWarning;
    return AppSection(
      title: reviewBizTypeLabel(task.bizType),
      trailing: ReviewPurposeBadge(purpose: task.purpose),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInfoRow.text(
            label: '市场与语言',
            text: '${adMarketLabel(task.market)} · ${task.language}',
          ),
          if (task.industry.isNotEmpty)
            AppInfoRow.text(label: '行业', text: adIndustryLabel(task.industry)),
          AppInfoRow.text(label: '版本', text: 'r${task.objectRevision}'),
          AppInfoRow.text(
            label: '状态',
            text: reviewTaskStatusLabel(task.status),
          ),
          if (task.escalationReason.isNotEmpty)
            AppInfoRow.text(
              label: '转人审原因',
              text: reviewEscalationLabel(task.escalationReason),
            ),
          if (task.purpose == 'report')
            AppInfoRow.text(label: '优先级', text: '${task.priority}（举报越多越高）'),
          if (reviewPurposeHint(task.purpose) case final hint?) ...[
            const SizedBox(height: AppTheme.space2),
            FAlert(
              key: Key('review-purpose-hint-${task.purpose}'),
              icon: const Icon(FLucideIcons.info),
              title: Text(hint),
            ),
          ],
          if (state.editable) ...[
            const SizedBox(height: AppTheme.space2),
            Row(
              children: [
                Icon(
                  FLucideIcons.timer,
                  size: 16,
                  color: expiring
                      ? theme.colors.destructive
                      : theme.colors.mutedForeground,
                ),
                const SizedBox(width: AppTheme.space1),
                Expanded(
                  child: Semantics(
                    liveRegion: expiring,
                    child: Text(
                      remaining == Duration.zero
                          ? '持有已到期'
                          : '持有剩余 ${_formatRemaining(remaining)}',
                      key: const Key('review-lease-remaining'),
                      style: theme.typography.body.sm.copyWith(
                        color: expiring ? theme.colors.destructive : null,
                        fontWeight: expiring ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
                FButton(
                  key: const Key('review-renew'),
                  size: FButtonSizeVariant.sm,
                  variant: FButtonVariant.outline,
                  mainAxisSize: MainAxisSize.min,
                  onPress: state.busy ? null : _renew,
                  child: const Text('续期'),
                ),
                const SizedBox(width: AppTheme.space2),
                FButton(
                  key: const Key('review-release'),
                  size: FButtonSizeVariant.sm,
                  variant: FButtonVariant.ghost,
                  mainAxisSize: MainAxisSize.min,
                  onPress: state.busy ? null : _release,
                  child: const Text('放弃'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _closureAlert(ReviewTaskClosure closure) => FAlert(
    key: Key('review-closure-${closure.name}'),
    variant: closure == ReviewTaskClosure.released
        ? FAlertVariant.primary
        : FAlertVariant.destructive,
    icon: const Icon(FLucideIcons.circleAlert),
    title: Text(reviewClosureMessage(closure)),
  );

  Widget _closed(ReviewTaskClosure closure) => Padding(
    padding: const EdgeInsets.all(AppTheme.pageInset),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _closureAlert(closure),
        const SizedBox(height: AppTheme.space3),
        FButton(
          variant: FButtonVariant.outline,
          onPress: () => context.go('/review'),
          child: const Text('返回队列'),
        ),
      ],
    ),
  );

  static String _formatRemaining(Duration remaining) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 以文字标签区分首次审核、质检、申诉、举报与回扫，不只依赖颜色（FX-113）。
class ReviewPurposeBadge extends StatelessWidget {
  final String purpose;

  const ReviewPurposeBadge({super.key, required this.purpose});

  @override
  Widget build(BuildContext context) {
    return FBadge(
      key: Key('review-purpose-$purpose'),
      variant: purpose == 'initial'
          ? FBadgeVariant.secondary
          : FBadgeVariant.primary,
      child: Text(reviewPurposeLabel(purpose)),
    );
  }
}

/// 质检复审与申诉任务展示原结论（FX-113）；申诉的原结论是被申诉的拒绝。
class OriginalDecisionSection extends StatelessWidget {
  final String purpose;
  final ReviewDecisionItem decision;
  final AdPolicyCatalog policies;

  const OriginalDecisionSection({
    super.key,
    required this.purpose,
    required this.decision,
    required this.policies,
  });

  @override
  Widget build(BuildContext context) {
    return AppSection(
      key: const Key('review-original-decision'),
      title: '原结论',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppInfoRow.text(
            label: '结论',
            text:
                '${reviewVerdictLabel(decision.verdict)}'
                '（${reviewSourceLabel(decision.source)}）',
          ),
          if (decision.policyCodes.isNotEmpty)
            AppInfoRow.text(
              label: '政策码',
              text: decision.policyCodes
                  .map((code) => '${policies.titleOf(code)}（$code）')
                  .join('\n'),
            ),
          if (decision.policyVersion.isNotEmpty)
            AppInfoRow.text(label: '政策版本', text: decision.policyVersion),
        ],
      ),
    );
  }
}
