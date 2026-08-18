import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exceptions.dart';
import '../../auth/application/auth_notifier.dart';
import '../data/message_models.dart';
import '../data/message_repository.dart';

typedef IdempotencyKeyFactory = String Function();

class ConversationListState {
  final List<ConversationSummary> conversations;
  final bool isLoading;
  final bool isLoadingMore;
  final int page;
  final int total;
  final String? error;

  const ConversationListState({
    this.conversations = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page = 0,
    this.total = 0,
    this.error,
  });

  bool get hasMore => conversations.length < total;

  ConversationListState copyWith({
    List<ConversationSummary>? conversations,
    bool? isLoading,
    bool? isLoadingMore,
    int? page,
    int? total,
    String? error,
    bool clearError = false,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      total: total ?? this.total,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ConversationListNotifier extends StateNotifier<ConversationListState> {
  final MessageDataSource _repository;
  final int pageSize;
  int _generation = 0;

  ConversationListNotifier({
    required MessageDataSource repository,
    this.pageSize = 20,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const ConversationListState()) {
    if (loadImmediately) unawaited(refresh());
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final result = await _repository.getConversations(pageSize: pageSize);
      if (generation != _generation) return;
      state = ConversationListState(
        conversations: _deduplicate(result.conversations),
        page: 1,
        total: result.total,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.isLoadingMore) return;
    final generation = _generation;
    final nextPage = state.page + 1;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    try {
      final result = await _repository.getConversations(
        page: nextPage,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        conversations: _deduplicate([
          ...state.conversations,
          ...result.conversations,
        ]),
        isLoadingMore: false,
        page: nextPage,
        total: result.total,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  void markConversationRead(int conversationId) {
    state = state.copyWith(
      conversations: [
        for (final conversation in state.conversations)
          if (conversation.id == conversationId)
            ConversationSummary(
              id: conversation.id,
              targetUserId: conversation.targetUserId,
              targetUserName: conversation.targetUserName,
              targetUserAvatar: conversation.targetUserAvatar,
              lastMessage: conversation.lastMessage,
              lastMessageTime: conversation.lastMessageTime,
              unreadCount: 0,
            )
          else
            conversation,
      ],
    );
  }

  static List<ConversationSummary> _deduplicate(
    List<ConversationSummary> conversations,
  ) {
    final seen = <int>{};
    return conversations.where((item) => seen.add(item.id)).toList();
  }
}

class MessageThreadState {
  final List<DirectMessage> messages;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isSending;
  final String? error;
  final String? sendError;
  final bool isMarkingRead;
  final String? readError;
  final SendMessageCommand? failedCommand;

  const MessageThreadState({
    this.messages = const [],
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.isSending = false,
    this.error,
    this.sendError,
    this.isMarkingRead = false,
    this.readError,
    this.failedCommand,
  });

  MessageThreadState copyWith({
    List<DirectMessage>? messages,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isSending,
    String? error,
    bool clearError = false,
    String? sendError,
    bool clearSendError = false,
    bool? isMarkingRead,
    String? readError,
    bool clearReadError = false,
    SendMessageCommand? failedCommand,
    bool clearFailedCommand = false,
  }) {
    return MessageThreadState(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
      sendError: clearSendError ? null : (sendError ?? this.sendError),
      isMarkingRead: isMarkingRead ?? this.isMarkingRead,
      readError: clearReadError ? null : (readError ?? this.readError),
      failedCommand: clearFailedCommand
          ? null
          : (failedCommand ?? this.failedCommand),
    );
  }
}

class MessageThreadNotifier extends StateNotifier<MessageThreadState> {
  final MessageDataSource _repository;
  final int conversationId;
  final int targetUserId;
  final int currentUserId;
  final int pageSize;
  final IdempotencyKeyFactory _createKey;
  final void Function()? _onMarkedRead;
  int _generation = 0;

  MessageThreadNotifier({
    required MessageDataSource repository,
    required this.conversationId,
    required this.targetUserId,
    required this.currentUserId,
    this.pageSize = 20,
    IdempotencyKeyFactory? createKey,
    void Function()? onMarkedRead,
    bool loadImmediately = true,
  }) : _repository = repository,
       _createKey = createKey ?? _defaultKey,
       _onMarkedRead = onMarkedRead,
       super(const MessageThreadState()) {
    if (loadImmediately) unawaited(refresh());
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingOlder: false,
      clearError: true,
    );
    try {
      final result = await _repository.getMessages(
        conversationId: conversationId,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        messages: _ordered(result.messages),
        hasMore: result.hasMore,
        isLoading: false,
        clearError: true,
      );
      await _markRead(generation);
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> retryMarkRead() => _markRead(_generation);

  Future<void> _markRead(int generation) async {
    state = state.copyWith(isMarkingRead: true, clearReadError: true);
    try {
      await _repository.markConversationRead(conversationId);
      if (generation != _generation) return;
      state = state.copyWith(isMarkingRead: false, clearReadError: true);
      _onMarkedRead?.call();
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isMarkingRead: false,
        readError: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> loadOlder() async {
    if (!state.hasMore ||
        state.messages.isEmpty ||
        state.isLoading ||
        state.isLoadingOlder) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingOlder: true, clearError: true);
    try {
      final result = await _repository.getMessages(
        conversationId: conversationId,
        lastId: state.messages.first.id,
        pageSize: pageSize,
      );
      if (generation != _generation) return;
      state = state.copyWith(
        messages: _ordered([...result.messages, ...state.messages]),
        hasMore: result.hasMore,
        isLoadingOlder: false,
      );
    } catch (error) {
      if (generation != _generation) return;
      state = state.copyWith(
        isLoadingOlder: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  Future<bool> send(
    String content, {
    int msgType = MessageTypes.text,
    int mediaId = 0,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty ||
        (msgType == MessageTypes.text && normalized.length > 1000) ||
        state.isSending ||
        conversationId <= 0 ||
        targetUserId <= 0 ||
        currentUserId <= 0) {
      return false;
    }
    final failed = state.failedCommand;
    final command =
        failed != null &&
            failed.receiverId == targetUserId &&
            failed.content == normalized &&
            failed.msgType == msgType &&
            failed.mediaId == mediaId
        ? failed
        : SendMessageCommand(
            receiverId: targetUserId,
            content: normalized,
            msgType: msgType,
            mediaId: mediaId,
            idempotencyKey: _createKey(),
          );
    return _send(command);
  }

  Future<bool> retryFailed() async {
    final command = state.failedCommand;
    if (command == null || state.isSending) return false;
    return _send(command);
  }

  Future<bool> _send(SendMessageCommand command) async {
    state = state.copyWith(
      isSending: true,
      clearSendError: true,
      failedCommand: command,
    );
    try {
      final id = await _repository.sendMessage(command);
      final sent = DirectMessage(
        id: id,
        conversationId: conversationId,
        senderId: currentUserId,
        receiverId: targetUserId,
        content: command.content,
        msgType: command.msgType,
        status: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      state = state.copyWith(
        messages: _ordered([...state.messages, sent]),
        isSending: false,
        clearSendError: true,
        clearFailedCommand: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        isSending: false,
        sendError: friendlyErrorMessage(error),
        failedCommand: command,
      );
      return false;
    }
  }

  static List<DirectMessage> _ordered(List<DirectMessage> messages) {
    final byId = <int, DirectMessage>{
      for (final message in messages) message.id: message,
    };
    final ordered = byId.values.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    return ordered;
  }

  static String _defaultKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'message-${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-$suffix';
  }
}

class MessageThreadKey {
  final int conversationId;
  final int targetUserId;
  final int currentUserId;

  const MessageThreadKey({
    required this.conversationId,
    required this.targetUserId,
    required this.currentUserId,
  });

  @override
  bool operator ==(Object other) {
    return other is MessageThreadKey &&
        other.conversationId == conversationId &&
        other.targetUserId == targetUserId &&
        other.currentUserId == currentUserId;
  }

  @override
  int get hashCode => Object.hash(conversationId, targetUserId, currentUserId);
}

class UnreadSummaryState {
  final UnreadSummary summary;
  final bool isLoading;
  final String? error;

  const UnreadSummaryState({
    this.summary = const UnreadSummary(),
    this.isLoading = false,
    this.error,
  });
}

class UnreadSummaryNotifier extends StateNotifier<UnreadSummaryState> {
  final MessageDataSource _repository;
  int _generation = 0;

  UnreadSummaryNotifier({
    required MessageDataSource repository,
    bool loadImmediately = true,
  }) : _repository = repository,
       super(const UnreadSummaryState()) {
    if (loadImmediately) unawaited(refresh());
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    state = UnreadSummaryState(summary: state.summary, isLoading: true);
    try {
      final summary = await _repository.getUnreadSummary();
      if (generation != _generation) return;
      state = UnreadSummaryState(summary: summary);
    } catch (error) {
      if (generation != _generation) return;
      state = UnreadSummaryState(
        summary: state.summary,
        error: friendlyErrorMessage(error),
      );
    }
  }
}

final messageRepositoryProvider = Provider<MessageDataSource>((ref) {
  return const MessageRepository();
});

final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((
      ref,
    ) {
      final authenticated = ref.watch(
        authNotifierProvider.select((state) => state.isAuthenticated),
      );
      return ConversationListNotifier(
        repository: ref.read(messageRepositoryProvider),
        loadImmediately: authenticated,
      );
    });

final unreadSummaryProvider =
    StateNotifierProvider<UnreadSummaryNotifier, UnreadSummaryState>((ref) {
      final authenticated = ref.watch(
        authNotifierProvider.select((state) => state.isAuthenticated),
      );
      return UnreadSummaryNotifier(
        repository: ref.read(messageRepositoryProvider),
        loadImmediately: authenticated,
      );
    });

final messageThreadProvider =
    StateNotifierProvider.family<
      MessageThreadNotifier,
      MessageThreadState,
      MessageThreadKey
    >((ref, key) {
      return MessageThreadNotifier(
        repository: ref.read(messageRepositoryProvider),
        conversationId: key.conversationId,
        targetUserId: key.targetUserId,
        currentUserId: key.currentUserId,
        onMarkedRead: () {
          ref
              .read(conversationListProvider.notifier)
              .markConversationRead(key.conversationId);
          unawaited(ref.read(unreadSummaryProvider.notifier).refresh());
        },
      );
    });
