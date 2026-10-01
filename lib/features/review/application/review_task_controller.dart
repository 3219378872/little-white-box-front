import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../sdk/data/gateway.dart';
import '../data/review_repository.dart';
import 'reviewer_access.dart';

/// 任务不可再操作的原因；出现后界面只允许返回队列，不自动重试（FX-111）。
enum ReviewTaskClosure { leaseLost, superseded, decided, forbidden, released }

String reviewClosureMessage(ReviewTaskClosure closure) => switch (closure) {
  ReviewTaskClosure.leaseLost => '持有已失效：任务可能已超时释放或由他人领取，本次结论未提交。',
  ReviewTaskClosure.superseded => '任务已作废：提交方已送审新版本，本任务无需再处理。',
  ReviewTaskClosure.decided => '任务已有结论，无需重复提交。',
  ReviewTaskClosure.forbidden => '你没有处理该任务的审核权限。',
  ReviewTaskClosure.released => '已放弃该任务，它会回到队列由其他审核员处理。',
};

class ReviewTaskState {
  final ReviewTaskItem? task;
  final bool loading;
  final bool busy;
  final String? error;
  final ReviewTaskClosure? closure;
  final ReviewDecisionResp? decision;

  const ReviewTaskState({
    this.task,
    this.loading = true,
    this.busy = false,
    this.error,
    this.closure,
    this.decision,
  });

  bool get editable =>
      task != null &&
      task!.status == 'claimed' &&
      closure == null &&
      decision == null;

  ReviewTaskState copyWith({
    ReviewTaskItem? task,
    bool? loading,
    bool? busy,
    String? error,
    bool clearError = false,
    ReviewTaskClosure? closure,
    ReviewDecisionResp? decision,
  }) {
    return ReviewTaskState(
      task: task ?? this.task,
      loading: loading ?? this.loading,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
      closure: closure ?? this.closure,
      decision: decision ?? this.decision,
    );
  }
}

class ReviewTaskController extends StateNotifier<ReviewTaskState> {
  final ReviewRepository _repository;
  final String taskId;
  final void Function() _onForbidden;

  /// 只在网络重试时复用；服务端已给出业务结论后丢弃。
  String? _decisionKey;
  String? _decisionFingerprint;

  ReviewTaskController({
    required ReviewRepository repository,
    required this.taskId,
    required void Function() onForbidden,
    bool loadImmediately = true,
  }) : _repository = repository,
       _onForbidden = onForbidden,
       super(const ReviewTaskState()) {
    if (loadImmediately) load();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final task = await _repository.getTask(taskId);
      if (!mounted) return;
      if (task == null) {
        state = state.copyWith(loading: false, error: '任务不存在或无权查看');
        return;
      }
      state = state.copyWith(
        task: task,
        loading: false,
        closure: switch (task.status) {
          'superseded' => ReviewTaskClosure.superseded,
          'decided' => ReviewTaskClosure.decided,
          _ => null,
        },
      );
    } catch (error) {
      if (!mounted) return;
      final closure = _closureOf(error);
      state = state.copyWith(
        loading: false,
        closure: closure,
        error: closure == null ? friendlyErrorMessage(error) : null,
      );
    }
  }

  Future<bool> renew() => _leaseCommand(() async {
    final task = state.task!;
    final renewed = await _repository.renew(task.taskId, task.leaseGeneration);
    if (renewed == null) throw const ApiException('续期失败');
    if (mounted) state = state.copyWith(task: renewed);
  });

  Future<bool> release() => _leaseCommand(() async {
    final task = state.task!;
    await _repository.release(task.taskId, task.leaseGeneration);
    if (mounted) state = state.copyWith(closure: ReviewTaskClosure.released);
  });

  /// 提交结论；拒绝必须至少选择一个政策码。
  Future<bool> submit({
    required String verdict,
    required List<String> policyCodes,
    String note = '',
    bool nominateSeed = false,
  }) async {
    if (verdict == 'reject' && policyCodes.isEmpty) {
      state = state.copyWith(error: '拒绝时必须选择至少一个政策码');
      return false;
    }
    return _leaseCommand(() async {
      final task = state.task!;
      final codes = verdict == 'reject'
          ? ([...policyCodes]..sort())
          : <String>[];
      final fingerprint = [
        task.leaseGeneration,
        verdict,
        codes.join(','),
        note.trim(),
        nominateSeed,
      ].join('|');
      if (_decisionFingerprint != fingerprint) {
        _decisionFingerprint = fingerprint;
        _decisionKey = newIdempotencyKey(24);
      }
      try {
        final decision = await _repository.decide(
          task.taskId,
          SubmitReviewDecisionReq(
            taskId: task.taskId,
            leaseGeneration: task.leaseGeneration,
            verdict: verdict,
            policyCodes: codes,
            note: note.trim(),
            nominateSeed: verdict == 'reject' && nominateSeed,
            idempotencyKey: _decisionKey!,
          ),
        );
        _clearDecisionKey();
        if (mounted) state = state.copyWith(decision: decision);
      } on ApiException catch (error) {
        if (error.code != null) _clearDecisionKey();
        rethrow;
      }
    });
  }

  void _clearDecisionKey() {
    _decisionKey = null;
    _decisionFingerprint = null;
  }

  Future<bool> _leaseCommand(Future<void> Function() command) async {
    if (!state.editable || state.busy) return false;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await command();
      if (mounted) state = state.copyWith(busy: false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final closure = _closureOf(error);
      state = state.copyWith(
        busy: false,
        closure: closure,
        error: closure == null ? friendlyErrorMessage(error) : null,
      );
      return false;
    }
  }

  ReviewTaskClosure? _closureOf(Object error) {
    if (error is! ApiException) return null;
    switch (error.code) {
      case ErrorCodes.reviewLeaseLost:
        return ReviewTaskClosure.leaseLost;
      case ErrorCodes.reviewTaskSuperseded:
        return ReviewTaskClosure.superseded;
      case ErrorCodes.reviewTaskDecided:
        return ReviewTaskClosure.decided;
      case ErrorCodes.reviewRoleRequired:
        _onForbidden();
        return ReviewTaskClosure.forbidden;
    }
    return null;
  }
}

final reviewTaskControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewTaskController, ReviewTaskState, String>((ref, taskId) {
      return ReviewTaskController(
        repository: ref.read(reviewRepositoryProvider),
        taskId: taskId,
        onForbidden: () => ref.invalidate(reviewerAccessProvider),
      );
    });
