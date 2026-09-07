import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

import 'assistant_dependencies.dart';
import 'assistant_state.dart';

export 'agent_consent_notifier.dart';
export 'assistant_dependencies.dart';
export 'assistant_state.dart';

part 'assistant_commands.dart';
part 'assistant_connection.dart';
part 'assistant_history.dart';
part 'assistant_messages.dart';
part 'assistant_reconciliation.dart';

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  final Map<String, String> _questionRequestIds = {};
  Timer? _waitingReconnect;
  final String _identityKey;
  StreamSubscription<AssistantRunEvent>? _subscription;
  int _generation = 0;
  int _connectionGeneration = 0;
  int _loadGeneration = 0;
  int _refreshGeneration = 0;
  int _olderGeneration = 0;
  int _lastSeq = 0;
  int _reconnects = 0;
  Object _subscribedRunId = 0;
  String _activeStreamId = '';
  final Set<String> _retiredStreamIds = <String>{};
  bool _usesStreamIds = false;
  Object _lastMessageId = 0;
  Object _activeRunFloorMessageId = 0;
  PendingAssistantCommand? _activeCommand;
  Future<bool>? _refreshFuture;
  bool _refreshRequested = false;

  AssistantNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
    String identityKey = 'direct',
  }) : _repository = repository,
       _createRequestId = createRequestId ?? _defaultRequestId,
       _identityKey = identityKey,
       super(const AssistantState());

  // Private parts share this notifier's state; no helper owns a second state copy.
  AssistantState get _value => state;
  set _value(AssistantState value) => state = value;

  void addPendingAttachment(PendingChatImage image) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, image],
    );
  }

  void removePendingAttachment(Object mediaId) {
    state = state.copyWith(
      pendingAttachments: [
        for (final item in state.pendingAttachments)
          if (item.mediaId != mediaId) item,
      ],
    );
  }

  Future<void> load() => _loadHistory();

  Future<bool> send(String message, {Object contextPostId = 0}) =>
      _sendCommand(message, contextPostId: contextPostId);

  Future<bool> retryPending() => _retryPendingCommand();

  Future<bool> answerQuestion(
    AssistantQuestionRequest question,
    List<AssistantQuestionAnswer> answers, {
    bool continueExpired = false,
  }) => _answerQuestionCommand(
    question,
    answers,
    continueExpired: continueExpired,
  );

  Future<bool> respondToConfirmation(String callId, bool approved) =>
      _respondToConfirmationCommand(callId, approved);

  Future<bool> stop() => _stopCommand();

  Future<void> clearHistory() => _clearHistoryCommand();

  Future<bool> undoMemoryChange(Object changeId) =>
      _undoMemoryChangeCommand(changeId);

  bool reconnectActiveRun() => _reconnectRun();

  static List<AssistantMessage> updateAll(
    List<AssistantMessage> messages,
    String id,
    AssistantMessage Function(AssistantMessage) update,
  ) => _updateAll(messages, id, update);

  Future<bool> refreshForThread(AssistantThreadSummary thread) =>
      _refreshThread(thread);

  Future<bool> loadOlderMessages() => _loadOlderHistory();

  Future<bool> refreshMessages() => _refreshHistory();

  @override
  void dispose() {
    _waitingReconnect?.cancel();
    _generation++;
    _connectionGeneration++;
    _loadGeneration++;
    _refreshGeneration++;
    _olderGeneration++;
    final subscription = _subscription;
    _subscription = null;
    _subscribedRunId = 0;
    _resetStreamTracking();
    unawaited(subscription?.cancel());
    super.dispose();
  }
}

final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      return AssistantNotifier(
        repository: ref.read(assistantRepositoryProvider),
        identityKey: identityKey,
      );
    });
