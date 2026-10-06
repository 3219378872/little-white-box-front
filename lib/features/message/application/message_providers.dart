import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';

import '../../../core/api/json_int64.dart';
import '../../auth/application/auth_notifier.dart';
import 'conversation_list_notifier.dart';
import 'message_dependencies.dart';
import 'message_thread_notifier.dart';
import 'unread_summary_notifier.dart';

/// 线程 provider 的 family 键；ID 统一规范为十进制字符串，使 int 与 String 形式命中同一实例。
class MessageThreadKey {
  final String conversationId;
  final String targetUserId;
  final String currentUserId;

  MessageThreadKey({
    required Object conversationId,
    required Object targetUserId,
    required Object currentUserId,
  }) : conversationId = jsonInt64Id(conversationId),
       targetUserId = jsonInt64Id(targetUserId),
       currentUserId = jsonInt64Id(currentUserId);

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

/// 当前账号的会话列表；未登录时不发请求，切换账号由身份变化重建。
final conversationListProvider =
    StateNotifierProvider<ConversationListNotifier, ConversationListState>((
      ref,
    ) {
      final identity = ref.watch(authenticatedSessionIdentityProvider);
      return ConversationListNotifier(
        repository: ref.read(messageRepositoryProvider),
        loadImmediately: identity != null,
      );
    });

/// 当前账号的未读汇总；与会话列表同样随登录身份重建。
final unreadSummaryProvider =
    StateNotifierProvider<UnreadSummaryNotifier, UnreadSummaryState>((ref) {
      final identity = ref.watch(authenticatedSessionIdentityProvider);
      return UnreadSummaryNotifier(
        repository: ref.read(messageRepositoryProvider),
        loadImmediately: identity != null,
      );
    });

/// 单个线程的状态；只有键中的当前用户就是登录用户时才自动加载，避免串号读取。
/// 标记已读成功后同步清零会话列表未读并刷新未读汇总。
final messageThreadProvider = StateNotifierProvider.autoDispose
    .family<MessageThreadNotifier, MessageThreadState, MessageThreadKey>((
      ref,
      key,
    ) {
      final identity = ref.watch(authenticatedSessionIdentityProvider);
      final auth = ref.read(authNotifierProvider);
      // 键里的当前用户必须就是登录用户，切号瞬间的旧键不触发读取与标记已读。
      final ownsThread =
          identity != null &&
          jsonInt64IsPositive(auth.userId ?? 0) &&
          jsonInt64Id(auth.userId!) == key.currentUserId;
      return MessageThreadNotifier(
        repository: ref.read(messageRepositoryProvider),
        conversationId: key.conversationId,
        targetUserId: key.targetUserId,
        currentUserId: key.currentUserId,
        loadImmediately: ownsThread,
        // 已读成功后同步会话列表与未读角标。
        onMarkedRead: () {
          ref
              .read(conversationListProvider.notifier)
              .markConversationRead(key.conversationId);
          unawaited(ref.read(unreadSummaryProvider.notifier).refresh());
        },
      );
    });
