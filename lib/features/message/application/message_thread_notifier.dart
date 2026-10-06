import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/json_int64.dart';
import '../data/message_models.dart';
import '../data/message_repository.dart';

/// 生成发送私信的幂等键；测试注入可预测的键以断言重试复用同一键。
typedef IdempotencyKeyFactory = String Function();

/// 单个私信线程的消息、发送与已读状态；[failedCommand] 保留失败的发送命令供重试复用幂等键。
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

/// 单个私信线程：加载与旧消息翻页、带幂等键的发送与重试、进入线程后的标记已读。
class MessageThreadNotifier extends StateNotifier<MessageThreadState> {
  final MessageDataSource _repository;
  final Object conversationId;
  final Object targetUserId;
  final Object currentUserId;
  final int pageSize;
  final IdempotencyKeyFactory _createKey;
  final void Function()? _onMarkedRead;
  int _loadGeneration = 0;
  int _readGeneration = 0;

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
    if (loadImmediately) unawaited(loadInitial());
  }

  /// 首屏与重试：读取最新一页消息，新一代请求使进行中的旧消息翻页失效。
  Future<void> loadInitial() async {
    final generation = ++_loadGeneration;
    final previousIds = state.messages
        .map((item) => jsonInt64Id(item.id))
        .toSet();
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
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        // Preserve sends accepted while this read was in flight. The server
        // wins for IDs present in both snapshots (status and timestamps).
        messages: _ordered([
          ...state.messages.where(
            (item) => !previousIds.contains(jsonInt64Id(item.id)),
          ),
          ...result.messages,
        ]),
        hasMore: result.hasMore,
        isLoading: false,
        clearError: true,
      );
      await _markRead();
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  /// 已读失败不影响阅读，页面横幅上的重试按钮调用此处。
  Future<void> retryMarkRead() => _markRead();

  Future<void> _markRead() async {
    final generation = ++_readGeneration;
    state = state.copyWith(isMarkingRead: true, clearReadError: true);
    try {
      await _repository.markConversationRead(conversationId);
      if (!mounted || generation != _readGeneration) return;
      state = state.copyWith(isMarkingRead: false, clearReadError: true);
      _onMarkedRead?.call();
    } catch (error) {
      if (!mounted || generation != _readGeneration) return;
      state = state.copyWith(
        isMarkingRead: false,
        readError: friendlyErrorMessage(error),
      );
    }
  }

  /// 以最早一条消息为游标向前翻页。
  Future<void> loadOlder() async {
    if (!state.hasMore ||
        state.messages.isEmpty ||
        state.isLoading ||
        state.isLoadingOlder) {
      return;
    }
    final generation = _loadGeneration;
    state = state.copyWith(isLoadingOlder: true, clearError: true);
    try {
      final result = await _repository.getMessages(
        conversationId: conversationId,
        lastId: state.messages.first.id,
        pageSize: pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        messages: _ordered([...result.messages, ...state.messages]),
        hasMore: result.hasMore,
        isLoadingOlder: false,
      );
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoadingOlder: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  /// 发送文本或已上传的媒体；与上次失败命令内容一致时复用其幂等键，避免重复投递。
  Future<bool> send(
    String content, {
    int msgType = MessageTypes.text,
    Object mediaId = 0,
  }) async {
    final normalized = content.trim();
    if (normalized.isEmpty ||
        (msgType == MessageTypes.text && normalized.length > 1000) ||
        state.isSending ||
        !jsonInt64IsPositive(conversationId) ||
        !jsonInt64IsPositive(targetUserId) ||
        !jsonInt64IsPositive(currentUserId)) {
      return false;
    }
    final failed = state.failedCommand;
    final command =
        failed != null &&
            jsonInt64Id(failed.receiverId) == jsonInt64Id(targetUserId) &&
            failed.content == normalized &&
            failed.msgType == msgType &&
            jsonInt64Id(failed.mediaId) == jsonInt64Id(mediaId)
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

  /// 用户取消失败的媒体发送时丢弃保留的命令，文本失败命令不受影响。
  void discardFailedMedia() {
    if (!state.isSending &&
        state.failedCommand != null &&
        state.failedCommand!.msgType != MessageTypes.text) {
      state = state.copyWith(clearFailedCommand: true, clearSendError: true);
    }
  }

  /// 原样重发上次失败的命令（同一幂等键）。
  Future<bool> retryFailed() async {
    final command = state.failedCommand;
    if (command == null || state.isSending) return false;
    return _send(command);
  }

  // 先把命令记为待重试，成功后追加本地消息并清除；失败保留命令与错误供横幅展示。
  Future<bool> _send(SendMessageCommand command) async {
    state = state.copyWith(
      isSending: true,
      clearSendError: true,
      failedCommand: command,
    );
    try {
      final id = await _repository.sendMessage(command);
      if (!mounted) return true;
      final sent = DirectMessage(
        id: id,
        conversationId: conversationId,
        senderId: currentUserId,
        receiverId: targetUserId,
        content: command.content,
        msgType: command.msgType,
        mediaId: command.mediaId,
        status: 0,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      state = state.copyWith(
        messages: _ordered([...state.messages, sent]),
        isSending: false,
        clearSendError: true,
        clearFailedCommand: true,
      );
      return true;
    } catch (error) {
      if (!mounted) return false;
      state = state.copyWith(
        isSending: false,
        sendError: friendlyErrorMessage(error),
        failedCommand: command,
      );
      return false;
    }
  }

  // 按 ID 去重后按 int64 数值升序排列；服务端快照与本地发送重叠时后出现者覆盖。
  static List<DirectMessage> _ordered(List<DirectMessage> messages) {
    final byId = <String, DirectMessage>{
      for (final message in messages) jsonInt64Id(message.id): message,
    };
    final ordered = byId.values.toList()
      ..sort(
        (left, right) =>
            _compareInt64Ids(jsonInt64Id(left.id), jsonInt64Id(right.id)),
      );
    return ordered;
  }

  // 等长十进制串按字典序比较即数值序，避免 int64 超出 JS 安全整数。
  static int _compareInt64Ids(String left, String right) {
    if (left.length != right.length) {
      return left.length.compareTo(right.length);
    }
    return left.compareTo(right);
  }

  // 发送私信的默认幂等键，前缀标明来自消息线程。
  static String _defaultKey() => newPrefixedRequestId('message');
}
