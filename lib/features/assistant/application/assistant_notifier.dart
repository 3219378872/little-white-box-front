import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
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
part 'assistant_run_reducer.dart';

/// Per-identity assistant conversation controller. Public methods are thin
/// entry points; the work lives in the part files (commands, history,
/// connection, run reducer and message transforms).
class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  // Answer fingerprint -> request id, so a retried answer reuses its id.
  final Map<String, String> _questionRequestIds = {};
  Timer? _waitingReconnect;
  final String _identityKey;
  StreamSubscription<AssistantRunEvent>? _subscription;
  // Generation counters guard async completions: subscription, connection
  // attempt, full load, incremental refresh and older-page loads respectively.
  int _generation = 0;
  int _connectionGeneration = 0;
  int _loadGeneration = 0;
  int _refreshGeneration = 0;
  int _olderGeneration = 0;
  // Highest event seq seen on the followed run; resume cursor for reconnects.
  int _lastSeq = 0;
  // In-place reconnects used by the current subscription (at most one).
  int _reconnects = 0;
  Object _subscribedRunId = 0;
  // Run whose stream failed non-retryably; thread polling must not
  // auto-reconnect it.
  Object _automaticReconnectBlockedRunId = 0;
  // Stream-id bookkeeping read and replaced by the run event reducer.
  AssistantStreamTracking _streams = AssistantStreamTracking.idle;
  // Newest persisted message id; cursor for incremental history refresh.
  Object _lastMessageId = 0;
  // Newest message id seen while the active run is open; a thread summary whose
  // last message is older than this is stale and must not settle the run.
  Object _activeRunFloorMessageId = 0;
  // Command that started the active run; restored for retry when the run fails
  // with AGENT_NOT_AUTHORIZED.
  PendingAssistantCommand? _activeCommand;
  // Coalesces overlapping refreshMessages calls into one draining loop.
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

  /// Queues an uploaded image for the next message.
  void addPendingAttachment(PendingChatImage image) {
    state = state.copyWith(
      pendingAttachments: [...state.pendingAttachments, image],
    );
  }

  /// Drops a queued image before it is sent.
  void removePendingAttachment(Object mediaId) {
    state = state.copyWith(
      pendingAttachments: [
        for (final item in state.pendingAttachments)
          if (item.mediaId != mediaId) item,
      ],
    );
  }

  /// Loads the thread and its latest history page, resuming the active run's
  /// stream when its answer is not persisted yet.
  Future<void> load() => _loadHistory();

  /// Sends [message], optionally about [contextPostId]. Resending the failed
  /// pending command reuses its request id. Returns whether it was accepted.
  Future<bool> send(String message, {Object contextPostId = 0}) =>
      _sendCommand(message, contextPostId: contextPostId);

  /// Retries the last failed send with its original request id.
  Future<bool> retryPending() => _retryPendingCommand();

  /// Submits answers to a question card; [continueExpired] resubmits an expired
  /// question as a new message.
  Future<bool> answerQuestion(
    AssistantQuestionRequest question,
    List<AssistantQuestionAnswer> answers, {
    bool continueExpired = false,
  }) => _answerQuestionCommand(
    question,
    answers,
    continueExpired: continueExpired,
  );

  /// Approves or declines a tool call awaiting confirmation; the optimistic
  /// `confirming` state rolls back on failure.
  Future<bool> respondToConfirmation(String callId, bool approved) =>
      _respondToConfirmationCommand(callId, approved);

  /// Cancels the active run. Returns true when nothing is running or the cancel
  /// succeeded.
  Future<bool> stop() => _stopCommand();

  /// Stops any active run, then deletes the whole history.
  Future<void> clearHistory() => _clearHistoryCommand();

  /// Reverts the memory change announced by a system notice.
  Future<bool> undoMemoryChange(Object changeId) =>
      _undoMemoryChangeCommand(changeId);

  /// Manually re-attaches to the active run's event stream after a disconnect.
  bool reconnectActiveRun() => _reconnectRun();

  /// Pure helper applying [update] to every message with [id].
  static List<AssistantMessage> updateAll(
    List<AssistantMessage> messages,
    String id,
    AssistantMessage Function(AssistantMessage) update,
  ) => _updateAll(messages, id, update);

  /// Reconciles with a polled thread summary: reloads on session or run change,
  /// otherwise syncs the phase, fetches newer messages and settles finished
  /// runs. Returns whether anything changed.
  Future<bool> refreshForThread(AssistantThreadSummary thread) =>
      _refreshThread(thread);

  /// Loads the previous history page.
  Future<bool> loadOlderMessages() => _loadOlderHistory();

  /// Fetches messages newer than the cursor; concurrent calls coalesce.
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

/// One notifier per signed-in identity; an identity change rebuilds it and the
/// old notifier cancels its stream on dispose.
final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
      final identityKey = ref.watch(assistantUserKeyProvider);
      return AssistantNotifier(
        repository: ref.read(assistantRepositoryProvider),
        identityKey: identityKey,
      );
    });
