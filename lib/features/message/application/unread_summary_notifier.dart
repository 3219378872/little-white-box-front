import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/message_models.dart';
import '../data/message_repository.dart';

/// 导航未读角标的数据快照；刷新失败时保留上次汇总只附带错误。
class UnreadSummaryState {
  final UnreadSummary summary;
  final bool isLoading;
  final String? error;

  const UnreadSummaryState({
    this.summary = const UnreadSummary(),
    this.isLoading = false,
    this.error,
  });
}

/// 私信与通知未读汇总，供导航角标和会话页头部展示。
class UnreadSummaryNotifier extends StateNotifier<UnreadSummaryState> {
  final MessageDataSource _repository;
  int _generation = 0;

  UnreadSummaryNotifier({
    required MessageDataSource repository,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const UnreadSummaryState()) {
    if (loadImmediately) unawaited(refresh());
  }

  /// 重新拉取未读汇总；并发刷新只采纳最新一次的结果。
  Future<void> refresh() async {
    final generation = ++_generation;
    state = UnreadSummaryState(summary: state.summary, isLoading: true);
    try {
      final summary = await _repository.getUnreadSummary();
      if (!mounted || generation != _generation) return;
      state = UnreadSummaryState(summary: summary);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = UnreadSummaryState(
        summary: state.summary,
        error: friendlyErrorMessage(error),
      );
    }
  }
}
