import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/search_models.dart';

/// 搜索结果中的标签条目：点击后以该标签名重新搜索。
///
/// A plain row keeps tags on the same 16px inset as post results.
class SearchTagTile extends StatelessWidget {
  final SearchTagResult tag;
  final ValueChanged<String> onSearchTag;

  const SearchTagTile({
    super.key,
    required this.tag,
    required this.onSearchTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      onPress: () => onSearchTag(tag.name),
      semanticsLabel: '${tag.name}，${tag.postCount} 篇帖子',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(FLucideIcons.hash, size: 18, color: theme.colors.primary),
            const SizedBox(width: AppTheme.space2),
            Expanded(
              child: Text(
                tag.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.md,
              ),
            ),
            Text(
              '${tag.postCount} 篇帖子',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(width: AppTheme.space1),
            Icon(
              FLucideIcons.chevronRight,
              size: 16,
              color: theme.colors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}
