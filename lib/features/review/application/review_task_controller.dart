import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/idempotency.dart';
import '../../../sdk/data/gateway.dart';
import '../data/review_repository.dart';
import 'reviewer_access.dart';
import 'review_dependencies.dart';

/// 任务不可再操作的原因；出现后界面只允许返回队列，不自动重试（FX-111）。
enum ReviewTaskClosure { leaseLost, superseded, decided, forbidden, released }

/// 关闭原因对应的说明文案。
String reviewClosureMessage(ReviewTaskClosure closure) => switch (closure) {
  ReviewTaskClosure.leaseLost => '持有已失效：任务可能已超时释放或由他人领取，本次结论未提交。',
  ReviewTaskClosure.superseded => '任务已作废：提交方已送审新版本，本任务无需再处理。',
  ReviewTaskClosure.decided => '任务已有结论，无需重复提交。',
  ReviewTaskClosure.forbidden => '你没有处理该任务的审核权限。',
  ReviewTaskClosure.released => '已放弃该任务，它会回到队列由其他审核员处理。',
};

/// 单个审核任务页的状态。
///
/// [isLoading] 为读取任务，[isBusy] 为续期、放弃或提交进行中；[closure] 或 [decision]
/// 出现后任务不可再操作。
class ReviewTaskState {
  final ReviewTaskItem? task;
  final bool isLoading;
  final bool isBusy;
  final String? error;
  final ReviewTaskClosure? closure;
  final ReviewDecisionResp? decision;

  const ReviewTaskState({
    this.task,
    this.isLoading = true,
    this.isBusy = false,
    this.error,
    this.closure,
    this.decision,
  });

  /// 仍由本人持有、且尚未关闭或提交结论时才可操作。
  bool get editable =>
      task != null &&
      task!.status == 'claimed' &&
      closure == null &&
      decision == null;

  ReviewTaskState copyWith({
    ReviewTaskItem? task,
    bool? isLoading,
    bool? isBusy,
    String? error,
    bool clearError = false,
    ReviewTaskClosure? closure,
    ReviewDecisionResp? decision,
  }) {
    return ReviewTaskState(
      task: task ?? this.task,
      isLoading: isLoading ?? this.isLoading,
      isBusy: isBusy ?? this.isBusy,
      error: clearError ? null : (error ?? this.error),
      closure: closure ?? this.closure,
      decision: decision ?? this.decision,
    );
  }
}

/// 审核任务详情的读取与持有期内命令（续期、放弃、提交结论），按任务 ID 隔离。
class ReviewTaskController extends StateNotifier<ReviewTaskState> {
  final ReviewRepository _repository;
  final String taskId;
  // 服务端判定无审核角色时回调，用于刷新授权让入口收起。
  final void Function() _onForbidden;

  // 提交结论的幂等键与对应输入指纹：只在网络重试时复用，服务端已给出业务结论后丢弃。
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

  /// 读取任务；已作废或已结案的任务直接标记关闭，权限与持有错误同样转为关闭原因。
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final task = await _repository.getTask(taskId);
      if (!mounted) return;
      if (task == null) {
        state = state.copyWith(isLoading: false, error: '任务不存在或无权查看');
        return;
      }
      state = state.copyWith(
        task: task,
        isLoading: false,
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
        isLoading: false,
        closure: closure,
        error: closure == null ? friendlyErrorMessage(error) : null,
      );
    }
  }

  /// 续期持有；成功后用服务端返回的任务替换，刷新到期时间。
  Future<bool> renew() => _leaseCommand(() async {
    final task = state.task!;
    final renewed = await _repository.renew(task.taskId, task.leaseGeneration);
    if (renewed == null) throw const ApiException('续期失败');
    if (mounted) state = state.copyWith(task: renewed);
  });

  /// 放弃持有；成功后标记为已放弃，由页面返回队列。
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
      // 只有拒绝携带政策码；排序后参与指纹，勾选顺序不影响幂等。
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
      // 指纹含持有代次：输入不变的重试复用同一幂等键，输入或持有变化则换新键。
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
            // 只有拒绝结论可以提名相似违规种子。
            nominateSeed: verdict == 'reject' && nominateSeed,
            idempotencyKey: _decisionKey!,
          ),
        );
        _clearDecisionKey();
        if (mounted) state = state.copyWith(decision: decision);
      } on ApiException catch (error) {
        // 有错误码说明服务端已处理该键，下次提交换新键；网络类失败保留键供重试。
        if (error.code != null) _clearDecisionKey();
        rethrow;
      }
    });
  }

  // 作废当前幂等键，下次提交视为新命令。
  void _clearDecisionKey() {
    _decisionKey = null;
    _decisionFingerprint = null;
  }

  // 持有期内命令的公共外壳：不可操作或忙碌时直接返回 false；失败时把权限与持有错误
  // 转为关闭原因，其余错误写入提示文案。
  Future<bool> _leaseCommand(Future<void> Function() command) async {
    if (!state.editable || state.isBusy) return false;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await command();
      if (mounted) state = state.copyWith(isBusy: false);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final closure = _closureOf(error);
      state = state.copyWith(
        isBusy: false,
        closure: closure,
        error: closure == null ? friendlyErrorMessage(error) : null,
      );
      return false;
    }
  }

  // 业务错误码映射为关闭原因；无审核角色时同时通知刷新授权。
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

/// 按任务 ID 隔离的任务控制器；离开任务页即释放。
final reviewTaskControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewTaskController, ReviewTaskState, String>((ref, taskId) {
      return ReviewTaskController(
        repository: ref.read(reviewRepositoryProvider),
        taskId: taskId,
        onForbidden: () => ref.invalidate(reviewerAccessProvider),
      );
    });
