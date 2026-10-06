import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/time_formatter.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/paginated_list.dart';
import '../../assistant/application/assistant_thread_notifier.dart';
import '../../assistant/data/assistant_models.dart';
import '../application/message_providers.dart';
import '../data/message_models.dart';
import '../../../core/router/app_routes.dart';

/// 消息模块的外壳：窄屏只显示会话列表或当前线程，宽屏（≥ lg 断点）左列表右线程并排。
class MessagesShell extends StatelessWidget {
  /// 当前打开的线程页；为空时宽屏右侧显示选择提示。
  final Widget? thread;

  /// 当前是否选中 Agent 会话，用于高亮置顶的 Agent 入口。
  final bool assistantSelected;

  const MessagesShell({super.key, this.thread, this.assistantSelected = false});

  @override
  Widget build(BuildContext context) {
    // 宽屏判断沿用主题的 lg 断点。
    final isDesktop =
        MediaQuery.sizeOf(context).width >= context.theme.breakpoints.lg;
    if (!isDesktop) {
      return thread ?? const ConversationsPage();
    }
    return Row(
      children: [
        SizedBox(
          width: 320,
          child: ConversationsPage(assistantSelected: assistantSelected),
        ),
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

/// 会话列表页：顶部通知未读角标、置顶的 Agent 会话与可分页、下拉刷新的私信会话列表。
class ConversationsPage extends ConsumerWidget {
  /// 接管会话点击（测试用）；为空时 push 到线程路由。
  final ValueChanged<ConversationSummary>? onOpenConversation;
  final bool assistantSelected;

  const ConversationsPage({
    super.key,
    this.onOpenConversation,
    this.assistantSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(conversationListProvider);
    final unread = ref.watch(unreadSummaryProvider);
    final assistant = ref.watch(assistantThreadProvider);
    final notifier = ref.read(conversationListProvider.notifier);
    final unreadNotifier = ref.read(unreadSummaryProvider.notifier);
    final assistantNotifier = ref.read(assistantThreadProvider.notifier);
    final selected = assistantSelected || _assistantRouteSelected(context);
    return Column(
      children: [
        // 头部：标题与通知未读数。
        FHeader(
          title: const Text('消息'),
          suffixes: [
            if (unread.summary.notificationUnread > 0)
              Center(
                child: AppBadge(
                  variant: FBadgeVariant.secondary,
                  child: Text('通知 ${unread.summary.notificationUnread}'),
                ),
              ),
          ],
        ),
        // 置顶的 Agent 会话入口。
        _AssistantPin(
          thread: assistant.thread,
          selected: selected,
          onPress: () => context.go(AppRoutes.assistant),
        ),
        Expanded(
          // 列表为空且加载失败时整体显示错误态，否则交给分页列表（含翻页失败的尾部重试）。
          child: state.error != null && state.conversations.isEmpty
              ? ErrorView(message: state.error!, onRetry: notifier.loadInitial)
              : PaginatedListView<ConversationSummary>(
                  items: state.conversations,
                  hasMore: state.hasMore,
                  isLoading: state.isLoading,
                  isLoadingMore: state.isLoadingMore,
                  error: state.error,
                  onLoadMore: notifier.loadMore,
                  // 下拉刷新同时更新会话、未读汇总与 Agent 会话摘要。
                  onRefresh: () async {
                    await Future.wait([
                      notifier.loadInitial(),
                      unreadNotifier.refresh(),
                      assistantNotifier.refresh(),
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
                    onPress: () => _open(context, conversation),
                  ),
                ),
        ),
      ],
    );
  }

  // 当前路由位于 Agent 页面时视为选中；无路由（如测试）时回退到构造参数。
  bool _assistantRouteSelected(BuildContext context) {
    final route = GoRouter.maybeOf(context);
    if (route == null) return assistantSelected;
    return route.routerDelegate.currentConfiguration.uri.path.startsWith(
      AppRoutes.assistant,
    );
  }

  // 打开会话线程，带上对方 ID 与昵称供线程页使用。
  void _open(BuildContext context, ConversationSummary conversation) {
    final callback = onOpenConversation;
    if (callback != null) {
      callback(conversation);
      return;
    }
    context.push(
      AppRoutes.messageThread(
        conversation.id,
        targetUserId: conversation.targetUserId,
        targetUserName: conversation.targetUserName,
      ),
    );
  }
}

// 会话列表顶部固定的 Agent 会话：展示最后一条预览与未读数，选中时加深底色。
class _AssistantPin extends StatelessWidget {
  final AssistantThreadSummary thread;
  final bool selected;
  final VoidCallback onPress;

  const _AssistantPin({
    required this.thread,
    required this.selected,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? theme.colors.secondary : theme.colors.muted,
        ),
        child: FItem(
          key: const Key('assistant-pinned-thread'),
          prefix: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colors.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              FLucideIcons.sparkles,
              color: theme.colors.primaryForeground,
              size: 24,
            ),
          ),
          title: const Text('小白盒 Agent'),
          subtitle: Text(
            thread.lastMessagePreview.isEmpty
                ? '随时问我任何问题'
                : thread.lastMessagePreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          details: thread.unreadCount > 0
              ? AppBadge(child: Text('${thread.unreadCount}'))
              : null,
          suffix: const Icon(FLucideIcons.chevronRight),
          onPress: onPress,
        ),
      ),
    );
  }
}

// 会话项右侧：最后消息时间与未读角标。
class _ConversationDetails extends StatelessWidget {
  final ConversationSummary conversation;

  const _ConversationDetails({required this.conversation});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(formatConversationTime(conversation.lastMessageTime)),
        if (conversation.unreadCount > 0) ...[
          const SizedBox(height: 4),
          AppBadge(child: Text('${conversation.unreadCount}')),
        ],
      ],
    );
  }
}
