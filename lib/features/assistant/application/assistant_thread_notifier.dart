import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

const assistantThreadPollInterval = Duration(seconds: 30);

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

  void applyUnread(int unreadCount) {
    state = state.copyWith(
      thread: AssistantThreadSummary(
        sessionId: state.thread.sessionId,
        unreadCount: unreadCount,
        lastMessageId: state.thread.lastMessageId,
        lastMessagePreview: state.thread.lastMessagePreview,
        lastMessageAtMs: state.thread.lastMessageAtMs,
        activeRunId: state.thread.activeRunId,
        activeRunStatus: state.thread.activeRunStatus,
        activeRunPhase: state.thread.activeRunPhase,
      ),
    );
  }
}

final assistantThreadProvider =
    StateNotifierProvider.autoDispose<
      AssistantThreadNotifier,
      AssistantThreadState
    >((ref) {
      final authenticated = ref.watch(
        authNotifierProvider.select((state) => state.isAuthenticated),
      );
      return AssistantThreadNotifier(
        repository: ref.read(assistantRepositoryProvider),
        loadImmediately: authenticated,
      );
    });

class AssistantThreadPollBinding extends ConsumerStatefulWidget {
  const AssistantThreadPollBinding({super.key});

  @override
  ConsumerState<AssistantThreadPollBinding> createState() =>
      _AssistantThreadPollBindingState();
}

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
