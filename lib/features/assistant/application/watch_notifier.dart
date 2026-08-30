import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

class WatchListState {
  final bool loading;
  final String? error;
  final List<WatchTask> items;

  const WatchListState({
    this.loading = false,
    this.error,
    this.items = const [],
  });

  WatchListState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<WatchTask>? items,
  }) {
    return WatchListState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
    );
  }
}

class WatchListNotifier extends StateNotifier<WatchListState> {
  final AssistantDataSource _repository;

  WatchListNotifier({required AssistantDataSource repository})
    : _repository = repository,
      super(const WatchListState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _repository.listWatches();
      if (!mounted) return;
      state = WatchListState(items: items);
    } catch (error) {
      if (!mounted) return;
      state = WatchListState(
        items: state.items,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<WatchTask> createTask({
    required String conditionType,
    required String targetType,
    Object targetId = 0,
    String targetText = '',
  }) async {
    try {
      final task = await _repository.createWatch(
        conditionType: conditionType,
        targetType: targetType,
        targetId: targetId,
        targetText: targetText,
      );
      await load();
      return task;
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }

  Future<void> setEnabled(WatchTask task, bool enabled) async {
    try {
      await _repository.updateWatch(id: task.id, enabled: enabled);
      await load();
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: friendlyErrorMessage(error));
      rethrow;
    }
  }

  Future<void> deleteTask(WatchTask task) async {
    try {
      await _repository.deleteWatch(task.id);
      await load();
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: friendlyErrorMessage(error));
      rethrow;
    }
  }
}

final watchListProvider =
    StateNotifierProvider.autoDispose<WatchListNotifier, WatchListState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      final notifier = WatchListNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
      if (identityKey.isNotEmpty) notifier.load();
      return notifier;
    });
