import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/collections/unique_by.dart';
import '../data/message_models.dart';
import '../data/message_repository.dart';

/// 会话列表页的分页快照；[hasMore] 由已加载条数与服务端总数推导。
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

/// 私信会话列表：首屏/刷新与翻页共用一代计数，刷新会让在途翻页结果作废。
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
    if (loadImmediately) unawaited(loadInitial());
  }

  /// 首屏、重试与下拉刷新：重新读取第一页会话，新一代请求使进行中的翻页失效。
  Future<void> loadInitial() async {
    final generation = ++_generation;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
    );
    try {
      final result = await _repository.getConversations(pageSize: pageSize);
      if (!mounted || generation != _generation) return;
      state = ConversationListState(
        conversations: _deduplicate(result.conversations),
        page: 1,
        total: result.total,
      );
    } catch (error) {
      if (!mounted || generation != _generation) return;
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
      if (!mounted || generation != _generation) return;
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
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        isLoadingMore: false,
        error: friendlyErrorMessage(error),
      );
    }
  }

  /// 线程标记已读成功后由线程 provider 回调，就地清零该会话未读数而不重新拉列表。
  void markConversationRead(Object conversationId) {
    state = state.copyWith(
      conversations: [
        for (final conversation in state.conversations)
          if (jsonInt64Id(conversation.id) == jsonInt64Id(conversationId))
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

  // 同一会话只保留首次出现的一条，避免刷新与推送合并后重复显示。
  static List<ConversationSummary> _deduplicate(
    List<ConversationSummary> conversations,
  ) {
    return uniqueBy(conversations, (item) => jsonInt64Id(item.id));
  }
}
