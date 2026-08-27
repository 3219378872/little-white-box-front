import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

class MemoryListState {
  final bool loading;
  final String? error;
  final List<MemoryRecord> items;

  const MemoryListState({
    this.loading = false,
    this.error,
    this.items = const [],
  });

  MemoryListState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<MemoryRecord>? items,
  }) {
    return MemoryListState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
    );
  }
}

class MemoryListNotifier extends StateNotifier<MemoryListState> {
  final AssistantDataSource _repository;

  MemoryListNotifier({required AssistantDataSource repository})
    : _repository = repository,
      super(const MemoryListState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final items = await _repository.listMemory();
      if (!mounted) return;
      state = MemoryListState(items: items);
    } catch (error) {
      if (!mounted) return;
      state = MemoryListState(
        items: state.items,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> updateRecord({
    required MemoryRecord record,
    String? value,
    double? score,
    bool? suppressed,
  }) async {
    try {
      await _repository.updateMemory(
        id: record.id,
        value: value ?? record.value,
        score: score ?? record.score,
        suppressed: suppressed ?? record.suppressed,
      );
      await load();
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: friendlyErrorMessage(error));
      rethrow;
    }
  }

  Future<void> deleteRecord(MemoryRecord record) async {
    try {
      await _repository.deleteMemory(record.id);
      await load();
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(error: friendlyErrorMessage(error));
      rethrow;
    }
  }
}

final memoryListProvider =
    StateNotifierProvider.autoDispose<MemoryListNotifier, MemoryListState>((
      ref,
    ) {
      final notifier = MemoryListNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
      notifier.load();
      return notifier;
    });
