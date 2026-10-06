import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';
import 'assistant_notifier.dart';

/// 记忆页状态：记录、各分区容量与最近一次可撤销的变更。
class MemoryListState {
  final bool isLoading;
  final String? error;
  final List<MemoryRecord> items;
  final List<MemoryCapacity> capacities;

  /// 最近一次写入的变更 ID；存在时记忆页提供撤销入口。
  final Object? lastChangeId;

  const MemoryListState({
    this.isLoading = false,
    this.error,
    this.items = const [],
    this.capacities = const [],
    this.lastChangeId,
  });

  MemoryListState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<MemoryRecord>? items,
    List<MemoryCapacity>? capacities,
    Object? lastChangeId,
    bool clearLastChangeId = false,
  }) {
    return MemoryListState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      items: items ?? this.items,
      capacities: capacities ?? this.capacities,
      lastChangeId: clearLastChangeId
          ? null
          : (lastChangeId ?? this.lastChangeId),
    );
  }
}

/// 记忆页的增删改与撤销；每次写入成功后整表重载。
class MemoryListNotifier extends StateNotifier<MemoryListState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  // 写入指纹 → requestId：失败后重试同一写入时复用，保证服务端幂等。
  final Map<String, String> _pendingRequestIds = {};
  int _loadGeneration = 0;

  MemoryListNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
  }) : _createRequestId = createRequestId ?? _defaultRequestId,
       _repository = repository,
       super(const MemoryListState());

  /// 拉取全部记忆与容量；失败时保留已有列表并记录错误。
  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repository.listMemory();
      if (!_isCurrentLoad(generation)) return;
      state = state.copyWith(
        isLoading: false,
        clearError: true,
        items: result.$1,
        capacities: result.$2,
      );
    } catch (error) {
      if (!_isCurrentLoad(generation)) return;
      state = state.copyWith(
        isLoading: false,
        items: state.items,
        capacities: state.capacities,
        error: friendlyErrorMessage(error),
      );
    }
  }

  /// 新增记忆；失败时记录错误并继续抛出，由调用方提示。
  Future<void> addRecord({
    required String target,
    required String content,
  }) async {
    final normalizedTarget = target.trim();
    final normalizedContent = content.trim();
    final fingerprint = [
      'add',
      normalizedTarget,
      normalizedContent,
    ].join('\u0000');
    final requestId = _requestIdFor(fingerprint);
    try {
      final result = await _repository.addMemory(
        target: normalizedTarget,
        content: normalizedContent,
        requestId: requestId,
      );
      _clearPendingCommand(fingerprint, requestId);
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

  /// 替换记忆内容，携带读取时的版本做并发校验；失败同样继续抛出。
  Future<void> updateRecord({
    required MemoryRecord record,
    required String content,
  }) async {
    final normalizedContent = content.trim();
    final fingerprint = [
      'replace',
      jsonInt64Id(record.id),
      '${record.version}',
      normalizedContent,
    ].join('\u0000');
    final requestId = _requestIdFor(fingerprint);
    try {
      final result = await _repository.replaceMemory(
        id: record.id,
        content: normalizedContent,
        version: record.version,
        requestId: requestId,
      );
      _clearPendingCommand(fingerprint, requestId);
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

  /// 删除记忆，携带版本做并发校验；失败同样继续抛出。
  Future<void> deleteRecord(MemoryRecord record) async {
    final fingerprint = [
      'remove',
      jsonInt64Id(record.id),
      '${record.version}',
    ].join('\u0000');
    final requestId = _requestIdFor(fingerprint);
    try {
      final result = await _repository.removeMemory(
        id: record.id,
        version: record.version,
        requestId: requestId,
      );
      _clearPendingCommand(fingerprint, requestId);
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

  /// 撤销最近一次写入并重载；失败同样继续抛出。
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

  // 同一写入指纹在成功前复用同一个 requestId。
  String _requestIdFor(String fingerprint) {
    return _pendingRequestIds.putIfAbsent(fingerprint, _createRequestId);
  }

  // 写入成功后释放指纹，之后相同内容视为新的写入。
  void _clearPendingCommand(String fingerprint, String requestId) {
    if (_pendingRequestIds[fingerprint] == requestId) {
      _pendingRequestIds.remove(fingerprint);
    }
  }

  // 丢弃已被新 load 取代或 notifier 已销毁后返回的结果。
  bool _isCurrentLoad(int generation) =>
      mounted && generation == _loadGeneration;

  // 记忆写入的默认幂等键。
  static String _defaultRequestId() => 'memory-${newIdempotencyKey(24)}';
}

/// 按登录身份重建；已登录则立即加载。
final memoryListProvider =
    StateNotifierProvider<MemoryListNotifier, MemoryListState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      final notifier = MemoryListNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
      if (identityKey.isNotEmpty) notifier.load();
      return notifier;
    });
