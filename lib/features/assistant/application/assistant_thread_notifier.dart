import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

/// 线程摘要的轮询间隔。
const assistantThreadPollInterval = Duration(seconds: 30);

/// 线程摘要及其加载状态，供底栏未读角标、消息列表入口与会话页对账使用。
class AssistantThreadState {
  final AssistantThreadSummary thread;
  final bool isLoading;
  final String? error;

  const AssistantThreadState({
    this.thread = const AssistantThreadSummary(),
    this.isLoading = false,
    this.error,
  });

  AssistantThreadState copyWith({
    AssistantThreadSummary? thread,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AssistantThreadState(
      thread: thread ?? this.thread,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// 拉取线程摘要；generation 保证并发刷新只采纳最后一次的结果。
class AssistantThreadNotifier extends StateNotifier<AssistantThreadState> {
  final AssistantDataSource _repository;
  int _generation = 0;

  AssistantThreadNotifier({
    required AssistantDataSource repository,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const AssistantThreadState()) {
    if (loadImmediately) unawaited(refresh());
  }

  /// 重新拉取摘要；失败时保留上一份摘要并记录错误。
  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final thread = await _repository.getThread();
      if (!mounted || generation != _generation) return;
      state = AssistantThreadState(thread: thread);
    } catch (error) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }
}

/// 按登录身份重建，未登录时不立即加载。
final assistantThreadProvider =
    StateNotifierProvider.autoDispose<
      AssistantThreadNotifier,
      AssistantThreadState
    >((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      return AssistantThreadNotifier(
        repository: ref.read(assistantRepositoryProvider),
        loadImmediately: identityKey.isNotEmpty,
      );
    });

/// 不渲染内容的轮询挂件：挂在主壳层期间，已登录时按间隔刷新线程摘要。
class AssistantThreadPollBinding extends ConsumerStatefulWidget {
  const AssistantThreadPollBinding({super.key});

  @override
  ConsumerState<AssistantThreadPollBinding> createState() =>
      _AssistantThreadPollBindingState();
}

// 持有轮询计时器，随挂件销毁取消。
class _AssistantThreadPollBindingState
    extends ConsumerState<AssistantThreadPollBinding> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(assistantThreadPollInterval, (_) {
      if (!mounted) return;
      if (!ref.read(authNotifierProvider).isAuthenticated) return;
      unawaited(ref.read(assistantThreadProvider.notifier).refresh());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
