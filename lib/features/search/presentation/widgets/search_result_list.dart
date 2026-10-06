import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/load_more_footer.dart';
import '../../data/search_models.dart';
import 'search_post_tile.dart';
import 'search_tag_tile.dart';
import 'search_user_tile.dart';

/// 搜索成功后的结果列表：按帖子、用户、标签分组，尾部是手动加载下一页。
///
/// 分组标题随搜索范围变化（综合页显示「相关用户/相关标签」）；导航与再搜索由页面回调处理。
class SearchResultList extends StatelessWidget {
  final SearchResults results;
  final SearchScope scope;
  final bool hasMore;
  final bool isLoadingMore;
  final String? loadMoreError;
  final VoidCallback onLoadMore;
  final ValueChanged<Object> onOpenPost;
  final ValueChanged<Object> onOpenUser;
  final ValueChanged<String> onSearchTag;
  final String keyword;

  const SearchResultList({
    super.key,
    required this.keyword,
    required this.results,
    required this.scope,
    required this.hasMore,
    required this.isLoadingMore,
    required this.loadMoreError,
    required this.onLoadMore,
    required this.onOpenPost,
    required this.onOpenUser,
    required this.onSearchTag,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    // 帖子分组
    if (results.posts.isNotEmpty) {
      children.add(const _SectionTitle('帖子'));
      children.addAll(
        results.posts.map(
          (post) => SearchPostTile(
            post: post,
            keyword: keyword,
            onOpenPost: onOpenPost,
            onOpenUser: onOpenUser,
          ),
        ),
      );
    }
    // 用户分组
    if (results.users.isNotEmpty) {
      children.add(_SectionTitle(scope == SearchScope.users ? '用户' : '相关用户'));
      children.addAll(
        results.users.map(
          (user) => SearchUserTile(user: user, onOpenUser: onOpenUser),
        ),
      );
    }
    // 标签分组：标签页最多返回 20 个，满额时提示只展示了前若干个
    if (results.tags.isNotEmpty) {
      children.add(_SectionTitle(scope == SearchScope.tags ? '标签' : '相关标签'));
      children.addAll(
        results.tags.map(
          (tag) => SearchTagTile(tag: tag, onSearchTag: onSearchTag),
        ),
      );
      if (scope == SearchScope.tags && results.tags.length >= 20) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
            child: Text(
              '只显示前 ${results.tags.length} 个标签',
              style: context.theme.typography.body.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
        );
      }
    }
    // 结果尾部：手动加载下一页，失败时原地重试。
    if (hasMore || isLoadingMore || loadMoreError != null) {
      children.add(
        LoadMoreFooter(
          isLoading: isLoadingMore,
          error: loadMoreError,
          onLoadMore: onLoadMore,
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        0,
        AppTheme.pageInset,
        AppTheme.space6,
      ),
      children: children,
    );
  }
}

// 结果分组标题，标记为语义 header 便于读屏跳转。
class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AppTheme.space4, 0, 0),
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: context.theme.typography.body.sm.copyWith(
            color: context.theme.colors.mutedForeground,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
