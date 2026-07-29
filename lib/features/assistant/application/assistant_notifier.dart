import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../data/assistant_models.dart';
import '../data/assistant_repository.dart';

enum AssistantMessageRole { user, assistant }

class AssistantMessage {
  final String id;
  final AssistantMessageRole role;
  final String text;
  final List<AssistantSourceReference> sources;
  final bool isStreaming;
  final bool isCanceled;
  final bool degraded;
  final String errorCode;

  const AssistantMessage({
    required this.id,
    required this.role,
    required this.text,
    this.sources = const [],
    this.isStreaming = false,
    this.isCanceled = false,
    this.degraded = false,
    this.errorCode = '',
  });

  AssistantMessage copyWith({
    String? text,
    List<AssistantSourceReference>? sources,
    bool? isStreaming,
    bool? isCanceled,
    bool? degraded,
    String? errorCode,
  }) {
    return AssistantMessage(
      id: id,
      role: role,
      text: text ?? this.text,
      sources: sources ?? this.sources,
      isStreaming: isStreaming ?? this.isStreaming,
      isCanceled: isCanceled ?? this.isCanceled,
      degraded: degraded ?? this.degraded,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

class AssistantState {
  final String conversationId;
  final List<AssistantMessage> messages;
  final bool isStreaming;
  final String? connectionError;

  const AssistantState({
    this.conversationId = '',
    this.messages = const [],
    this.isStreaming = false,
    this.connectionError,
  });

  AssistantState copyWith({
    String? conversationId,
    List<AssistantMessage>? messages,
    bool? isStreaming,
    String? connectionError,
    bool clearConnectionError = false,
  }) {
    return AssistantState(
      conversationId: conversationId ?? this.conversationId,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      connectionError: clearConnectionError
          ? null
          : (connectionError ?? this.connectionError),
    );
  }
}

class AssistantNotifier extends StateNotifier<AssistantState> {
  final AssistantDataSource _repository;
  final String Function() _createRequestId;
  StreamSubscription<AssistantChatEvent>? _subscription;
  int _generation = 0;

  AssistantNotifier({
    required AssistantDataSource repository,
    String Function()? createRequestId,
  }) : _repository = repository,
       _createRequestId = createRequestId ?? _defaultRequestId,
       super(const AssistantState());

  bool send(String message) {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 2000 || state.isStreaming) {
      return false;
    }

    final requestId = _createRequestId();
    final generation = ++_generation;
    final responseId = 'assistant-$requestId';
    state = state.copyWith(
      messages: [
        ...state.messages,
        AssistantMessage(
          id: 'user-$requestId',
          role: AssistantMessageRole.user,
          text: normalized,
        ),
        AssistantMessage(
          id: responseId,
          role: AssistantMessageRole.assistant,
          text: '',
          isStreaming: true,
        ),
      ],
      isStreaming: true,
      clearConnectionError: true,
    );

    final stream = _repository.chat(
      message: normalized,
      requestId: requestId,
      conversationId: state.conversationId,
    );
    _subscription = stream.listen(
      (event) {
        if (generation != _generation) return;
        _applyEvent(responseId, event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation) return;
        _finishWithTransportError(responseId, friendlyErrorMessage(error));
      },
      onDone: () {
        if (generation != _generation || !state.isStreaming) return;
        _finishWithTransportError(responseId, 'Assistant 连接意外中断');
      },
      cancelOnError: false,
    );
    return true;
  }

  Future<void> cancel() async {
    if (!state.isStreaming) return;
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    state = state.copyWith(
      messages: _updateLastAssistant(
        (message) => message.copyWith(
          text: message.text.isEmpty ? '已取消' : message.text,
          isStreaming: false,
          isCanceled: true,
        ),
      ),
      isStreaming: false,
      clearConnectionError: true,
    );
  }

  void clear() {
    unawaited(cancel());
    state = const AssistantState();
  }

  void _applyEvent(String responseId, AssistantChatEvent event) {
    final conversationId = event.conversationId.isEmpty
        ? state.conversationId
        : event.conversationId;
    switch (event.type) {
      case AssistantEventType.token:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(text: '${message.text}${event.text}'),
          ),
        );
      case AssistantEventType.source:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(responseId, (message) {
            final source = event.source!;
            return message.sources.contains(source)
                ? message
                : message.copyWith(sources: [...message.sources, source]);
          }),
        );
      case AssistantEventType.done:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) =>
                message.copyWith(isStreaming: false, degraded: event.degraded),
          ),
          isStreaming: false,
        );
      case AssistantEventType.error:
        state = state.copyWith(
          conversationId: conversationId,
          messages: _updateMessage(
            responseId,
            (message) => message.copyWith(
              text: message.text.isEmpty ? event.text : message.text,
              isStreaming: false,
              degraded: true,
              errorCode: event.errorCode,
            ),
          ),
          isStreaming: false,
          connectionError: event.text,
        );
    }
  }

  void _finishWithTransportError(String responseId, String error) {
    state = state.copyWith(
      messages: _updateMessage(
        responseId,
        (message) => message.copyWith(
          text: message.text.isEmpty ? '响应中断' : message.text,
          isStreaming: false,
          degraded: true,
          errorCode: 'STREAM_DISCONNECTED',
        ),
      ),
      isStreaming: false,
      connectionError: error,
    );
  }

  List<AssistantMessage> _updateMessage(
    String id,
    AssistantMessage Function(AssistantMessage) update,
  ) {
    return [
      for (final message in state.messages)
        if (message.id == id) update(message) else message,
    ];
  }

  List<AssistantMessage> _updateLastAssistant(
    AssistantMessage Function(AssistantMessage) update,
  ) {
    final messages = [...state.messages];
    final index = messages.lastIndexWhere(
      (message) => message.role == AssistantMessageRole.assistant,
    );
    if (index >= 0) messages[index] = update(messages[index]);
    return messages;
  }

  static String _defaultRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'assistant-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

final assistantRepositoryProvider = Provider<AssistantDataSource>((ref) {
  return AssistantRepository();
});

final assistantNotifierProvider =
    StateNotifierProvider<AssistantNotifier, AssistantState>((ref) {
      return AssistantNotifier(
        repository: ref.read(assistantRepositoryProvider),
      );
    });
