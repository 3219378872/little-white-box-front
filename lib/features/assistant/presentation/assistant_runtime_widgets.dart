import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/api/json_int64.dart';
import '../application/assistant_notifier.dart';
import '../data/assistant_models.dart';

const agentConsentDisclosure = '''
Agent 将以你的身份执行以下操作，权限不超过你的账号：

· Search：search_posts、search_users、search_tags、get_post、get_post_comments、web_search、search_history
· UserState：get_my_favorites、get_my_likes、get_my_following、get_my_posts
· Recommend：recommend_posts、similar_posts、compare_posts
· Memory：读取和写入 MEMORY/USER 自然语言记忆
· Watch：创建和管理条件追踪（命中只出现在小白盒 Agent 线程）
· Write：create_post、update_post、delete_post——每次删除都会先向你逐次确认

网络检索只作研究素材，不能当作社区证据。来源只展示服务端给出的来源卡。长任务受轮次、工具和时长预算约束。
你可以随时撤销授权；确认后立即生效。''';

class AssistantSourceCards extends StatelessWidget {
  final AssistantMessage message;
  final bool Function(AssistantSourceCard) canOpen;
  final ValueChanged<AssistantSourceCard> onOpen;
  final ValueChanged<AssistantSourceCard> onDislike;

  const AssistantSourceCards({
    super.key,
    required this.message,
    required this.canOpen,
    required this.onOpen,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    if (message.sources.isEmpty) return const SizedBox.shrink();
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final source in message.sources) ...[
          const SizedBox(height: 8),
          DecoratedBox(
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
                        source.kind == 'web'
                            ? FLucideIcons.globe
                            : source.isRecommend
                            ? FLucideIcons.sparkles
                            : FLucideIcons.fileText,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          source.title.isEmpty
                              ? '${source.kind}:${source.authorityId}'
                              : source.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (source.handle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      source.handle,
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                  if (canOpen(source) || source.isRecommend) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (canOpen(source))
                          FButton(
                            variant: .secondary,
                            size: .sm,
                            onPress: () => onOpen(source),
                            child: const Text('打开帖子'),
                          ),
                        if (source.isRecommend && source.isVerifiedPost) ...[
                          FButton(
                            key: Key(
                              'assistant-card-dislike-${jsonInt64Id(source.postId)}',
                            ),
                            variant: .ghost,
                            size: .sm,
                            onPress: () => onDislike(source),
                            child: const Text('不喜欢'),
                          ),
                          FButton(
                            key: Key(
                              'assistant-card-uninterested-${jsonInt64Id(source.postId)}',
                            ),
                            variant: .ghost,
                            size: .sm,
                            onPress: () => onDislike(source),
                            child: const Text('不感兴趣'),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
