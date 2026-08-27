import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/api/json_int64.dart';
import '../application/assistant_notifier.dart';
import '../data/assistant_models.dart';

const agentConsentDisclosure = '''
Agent 将以你的身份执行以下操作，权限不超过你的账号：

· Search：search_posts、search_users、search_tags、get_post、get_post_comments、web_search
· UserState：get_my_favorites、get_my_likes、get_my_following、get_my_posts
· Recommend：recommend_posts、similar_posts、compare_posts
· Memory：get_memory、add_memory、update_memory、delete_memory（将保存用户可见的结构化记忆）
· Watch：create_watch_task、list_watch_tasks、update_watch_task、delete_watch_task（将创建仅在助手内投递的条件追踪）
· Write：create_post、update_post、delete_post——每次删除都会先向你逐次确认

网络检索只作研究素材，不能当作社区证据。命中只出现在助手收件箱，不会写入私信或系统通知。
你可以随时撤销授权；确认后立即生效。''';

class AssistantCardsAndActions extends StatelessWidget {
  final AssistantMessage message;
  final ValueChanged<AssistantStructuredAction> onAction;
  final ValueChanged<AssistantStructuredCard> onDislike;
  final ValueChanged<AssistantWatchHitNotice> onOpenHit;

  const AssistantCardsAndActions({
    super.key,
    required this.message,
    required this.onAction,
    required this.onDislike,
    required this.onOpenHit,
  });

  @override
  Widget build(BuildContext context) {
    if (message.cards.isEmpty &&
        message.actions.isEmpty &&
        message.watchHits.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final card in message.cards) ...[
          const SizedBox(height: 8),
          _CardTile(
            card: card,
            onOpen: card.hasVerifiedPost
                ? () => onAction(
                    AssistantStructuredAction(
                      action: 'open_post',
                      postId: card.postId,
                    ),
                  )
                : null,
            onDislike: card.isRecommend && card.hasVerifiedPost
                ? () => onDislike(card)
                : null,
          ),
        ],
        if (message.actions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final action in message.actions)
                FButton(
                  variant: .secondary,
                  size: .sm,
                  onPress: () => onAction(action),
                  child: Text(_actionLabel(action)),
                ),
            ],
          ),
        ],
        for (final hit in message.watchHits) ...[
          const SizedBox(height: 8),
          FButton(
            variant: .ghost,
            onPress: hit.hasVerifiedPost ? () => onOpenHit(hit) : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FLucideIcons.bell, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hit.title.isEmpty ? '追踪命中' : hit.title,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hit.hasVerifiedPost) ...[
                  const SizedBox(width: 6),
                  Text(
                    'post:${jsonInt64Id(hit.postId)}',
                    style: theme.typography.body.xs.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  final AssistantStructuredCard card;
  final VoidCallback? onOpen;
  final VoidCallback? onDislike;

  const _CardTile({required this.card, this.onOpen, this.onDislike});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final title = card.title.isEmpty ? '结构化卡片' : card.title;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.muted.withValues(alpha: .35),
        borderRadius: theme.style.borderRadius.md,
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  card.isRecommend
                      ? FLucideIcons.sparkles
                      : FLucideIcons.layoutGrid,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (card.summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                card.summary,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
            if (onOpen != null || onDislike != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (onOpen != null)
                    FButton(
                      variant: .secondary,
                      size: .sm,
                      onPress: onOpen,
                      child: const Text('打开帖子'),
                    ),
                  if (onDislike != null) ...[
                    FButton(
                      key: Key(
                        'assistant-card-dislike-${jsonInt64Id(card.postId)}',
                      ),
                      variant: .ghost,
                      size: .sm,
                      onPress: onDislike,
                      child: const Text('不喜欢'),
                    ),
                    FButton(
                      key: Key(
                        'assistant-card-uninterested-${jsonInt64Id(card.postId)}',
                      ),
                      variant: .ghost,
                      size: .sm,
                      onPress: onDislike,
                      child: const Text('不感兴趣'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _actionLabel(AssistantStructuredAction action) {
  return switch (action.action) {
    'open_post' => '打开帖子',
    'create_watch' => '创建追踪',
    'watch_author' => '盯作者',
    'watch_tag' => '盯标签',
    'favorite' => '收藏',
    'dislike' => '不喜欢',
    'not_interested' => '不感兴趣',
    _ => action.action,
  };
}
