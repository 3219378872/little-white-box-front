import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/api/json_int64.dart';
import '../../../../core/widgets/cached_avatar.dart';
import '../../data/search_models.dart';
import '../search_highlight.dart';

/// 搜索结果中的帖子条目：作者行、高亮标题、正文命中片段与互动计数。
///
/// 标题按用户输入的关键词本地高亮，正文片段使用服务端 `<em>` 高亮标记。
class SearchPostTile extends StatelessWidget {
  final SearchPostResult post;
  final String keyword;
  final ValueChanged<Object> onOpenPost;
  final ValueChanged<Object> onOpenUser;

  const SearchPostTile({
    super.key,
    required this.post,
    required this.keyword,
    required this.onOpenPost,
    required this.onOpenUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final mark = TextStyle(
      color: theme.colors.primary,
      fontWeight: FontWeight.w600,
    );
    final highlight = parseEmHighlight(post.contentHighlight.trim(), mark);
    final avatar = CachedAvatar(
      url: post.authorAvatar,
      name: post.displayAuthor,
      radius: 10,
    );
    return FTappable(
      onPress: () => onOpenPost(post.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 作者行：匿名或缺失作者 ID 时不可点击
            FTappable(
              onPress: jsonInt64IsPositive(post.authorId)
                  ? () => onOpenUser(post.authorId)
                  : null,
              child: Row(
                children: [
                  avatar,
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      post.displayAuthor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: highlightKeyword(
                  post.title.isEmpty ? '未命名帖子' : post.title,
                  keyword,
                  mark,
                ),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (highlight.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: highlight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.secondaryForeground,
                  height: 1.6,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${post.likeCount} 赞 · ${post.commentCount} 评论',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
