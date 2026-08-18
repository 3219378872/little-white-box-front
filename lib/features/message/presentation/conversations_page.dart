import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/paginated_list.dart';
import '../application/message_notifiers.dart';
import '../data/message_models.dart';

class MessagesShell extends StatelessWidget {
  final Widget? thread;

  const MessagesShell({super.key, this.thread});

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= context.theme.breakpoints.lg;
    if (!isDesktop) {
      return thread ?? const ConversationsPage();
    }
    return Row(
      children: [
        const SizedBox(width: 320, child: ConversationsPage()),
        ColoredBox(
          color: context.theme.colors.border,
          child: const SizedBox(width: 1, height: double.infinity),
        ),
        Expanded(
          child:
              thread ??
              const EmptyView(
                message: '选择一个会话开始聊天',
                icon: FLucideIcons.messagesSquare,
              ),
        ),
      ],
    );
  }
}

class ConversationsPage extends ConsumerWidget {
  final ValueChanged<ConversationSummary>? onOpenConversation;

  const ConversationsPage({super.key, this.onOpenConversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationListProvider);
    final unread = ref.watch(unreadSummaryProvider);
    final notifier = ref.read(conversationListProvider.notifier);
    final unreadNotifier = ref.read(unreadSummaryProvider.notifier);
    return Column(
      children: [
        FHeader(
          title: const Text('私信'),
          suffixes: [
            if (unread.summary.notificationUnread > 0)
              Center(
                child: FBadge(
                  variant: FBadgeVariant.secondary,
                  child: Text('通知 ${unread.summary.notificationUnread}'),
                ),
              ),
            FHeaderAction(
              icon: const Icon(FLucideIcons.sparkles),
              semanticsLabel: '打开 Assistant',
              onPress: () => context.go('/assistant'),
            ),
          ],
        ),
        Expanded(
          child: state.error != null && state.conversations.isEmpty
              ? ErrorView(message: state.error!, onRetry: notifier.refresh)
              : PaginatedListView<ConversationSummary>(
                  items: state.conversations,
                  hasMore: state.hasMore,
                  isLoading: state.isLoading,
                  isLoadingMore: state.isLoadingMore,
                  error: state.error,
                  onLoadMore: notifier.loadMore,
                  onRefresh: () async {
                    await Future.wait([
                      notifier.refresh(),
                      unreadNotifier.refresh(),
                    ]);
                  },
                  emptyWidget: const EmptyView(
                    message: '暂无私信',
                    icon: FLucideIcons.messagesSquare,
                  ),
                  itemBuilder: (context, conversation) => FItem(
                    prefix: CachedAvatar(
                      url: conversation.targetUserAvatar,
                      name: conversation.targetUserName,
                      radius: 22,
                    ),
                    title: Text(
                      conversation.targetUserName.isEmpty
                          ? '用户 ${conversation.targetUserId}'
                          : conversation.targetUserName,
                    ),
                    subtitle: Text(
                      conversation.lastMessage.isEmpty
                          ? '暂无消息'
                          : conversation.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    details: _ConversationDetails(conversation: conversation),
                    suffix: const Icon(FLucideIcons.chevronRight),
                    onPress: () => _open(context, conversation),
                  ),
                ),
        ),
      ],
    );
  }

  void _open(BuildContext context, ConversationSummary conversation) {
    final callback = onOpenConversation;
    if (callback != null) {
      callback(conversation);
      return;
    }
    context.push(
      Uri(
        path: '/messages/${conversation.id}',
        queryParameters: {
          'targetUserId': '${conversation.targetUserId}',
          'targetUserName': conversation.targetUserName,
        },
      ).toString(),
    );
  }
}

class _ConversationDetails extends StatelessWidget {
  final ConversationSummary conversation;

  const _ConversationDetails({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(_shortTime(conversation.lastMessageTime)),
        if (conversation.unreadCount > 0) ...[
          const SizedBox(height: 4),
          FBadge(child: Text('${conversation.unreadCount}')),
        ],
      ],
    );
  }
}

String _shortTime(int seconds) {
  if (seconds <= 0) return '';
  final value = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
  final now = DateTime.now();
  if (value.year == now.year &&
      value.month == now.month &&
      value.day == now.day) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }
  return '${value.month}/${value.day}';
}
