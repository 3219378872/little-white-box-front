import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

class MemoryListState {
  final bool loading;
  final String? error;
  final List<MemoryRecord> items;
  final List<MemoryCapacity> capacities;
  final Object? lastChangeId;

  const MemoryListState({
    this.loading = false,
    this.error,
    this.items = const [],
    this.capacities = const [],
    this.lastChangeId,
  });

  MemoryListState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    List<MemoryRecord>? items,
    List<MemoryCapacity>? capacities,
    Object? lastChangeId,
  }) {
    return MemoryListState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      capacities: capacities ?? this.capacities,
      lastChangeId: lastChangeId ?? this.lastChangeId,
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
      final result = await _repository.listMemory();
      if (!mounted) return;
      state = MemoryListState(items: result.$1, capacities: result.$2);
    } catch (error) {
      if (!mounted) return;
      state = MemoryListState(
        items: state.items,
        capacities: state.capacities,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> addRecord({
    required String target,
    required String content,
  }) async {
    try {
      final result = await _repository.addMemory(
        target: target,
        content: content,
      );
      if (!mounted) return;
      state = state.copyWith(lastChangeId: result.changeId);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }

  Future<void> updateRecord({
    required MemoryRecord record,
    required String content,
  }) async {
    try {
      final result = await _repository.replaceMemory(
        id: record.id,
        content: content,
        version: record.version,
      );
      if (!mounted) return;
      state = state.copyWith(lastChangeId: result.changeId);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }

  Future<void> deleteRecord(MemoryRecord record) async {
    try {
      final result = await _repository.removeMemory(
        id: record.id,
        version: record.version,
      );
      if (!mounted) return;
      state = state.copyWith(lastChangeId: result.changeId);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }

  Future<void> undoLastChange() async {
    final changeId = state.lastChangeId;
    if (changeId == null) return;
    try {
      await _repository.undoMemoryChange(changeId);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }
}

final memoryListProvider =
    StateNotifierProvider.autoDispose<MemoryListNotifier, MemoryListState>((
      ref,
    ) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      final notifier = MemoryListNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
      if (identityKey.isNotEmpty) notifier.load();
      return notifier;
    });
