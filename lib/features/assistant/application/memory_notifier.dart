import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
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
    bool clearLastChangeId = false,
  }) {
    return MemoryListState(
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      capacities: capacities ?? this.capacities,
      lastChangeId: clearLastChangeId
          ? null
          : (lastChangeId ?? this.lastChangeId),
    );
  }
}

class MemoryListNotifier extends StateNotifier<MemoryListState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  String? _pendingCommandFingerprint;
  String? _pendingRequestId;

  MemoryListNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
  }) : _createRequestId = createRequestId ?? _defaultRequestId,
       _repository = repository,
       super(const MemoryListState());

  Future<void> load() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final result = await _repository.listMemory();
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        clearError: true,
        items: result.$1,
        capacities: result.$2,
      );
    } catch (error) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
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
    final normalizedTarget = target.trim();
    final normalizedContent = content.trim();
    final requestId = _requestIdFor(
      ['add', normalizedTarget, normalizedContent].join('\u0000'),
    );
    try {
      final result = await _repository.addMemory(
        target: normalizedTarget,
        content: normalizedContent,
        requestId: requestId,
      );
      _clearPendingCommand();
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
    final normalizedContent = content.trim();
    final requestId = _requestIdFor(
      [
        'replace',
        jsonInt64Id(record.id),
        '${record.version}',
        normalizedContent,
      ].join('\u0000'),
    );
    try {
      final result = await _repository.replaceMemory(
        id: record.id,
        content: normalizedContent,
        version: record.version,
        requestId: requestId,
      );
      _clearPendingCommand();
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
    final requestId = _requestIdFor(
      ['remove', jsonInt64Id(record.id), '${record.version}'].join('\u0000'),
    );
    try {
      final result = await _repository.removeMemory(
        id: record.id,
        version: record.version,
        requestId: requestId,
      );
      _clearPendingCommand();
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
      if (!mounted) return;
      state = state.copyWith(clearLastChangeId: true, clearError: true);
      await load();
    } catch (error) {
      if (mounted) {
        state = state.copyWith(error: friendlyErrorMessage(error));
      }
      rethrow;
    }
  }

  String _requestIdFor(String fingerprint) {
    if (_pendingCommandFingerprint != fingerprint ||
        _pendingRequestId == null) {
      _pendingCommandFingerprint = fingerprint;
      _pendingRequestId = _createRequestId();
    }
    return _pendingRequestId!;
  }

  void _clearPendingCommand() {
    _pendingCommandFingerprint = null;
    _pendingRequestId = null;
  }

  static String _defaultRequestId() => 'memory-${newIdempotencyKey(24)}';
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
