import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/load_more_footer.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/search_notifier.dart';
import '../data/search_models.dart';
import 'search_highlight.dart';
import '../../../core/router/app_routes.dart';

class SearchPage extends ConsumerStatefulWidget {
  final ValueChanged<Object>? onOpenPost;
  final ValueChanged<Object>? onOpenUser;

  const SearchPage({super.key, this.onOpenPost, this.onOpenUser});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Keep the field in sync with a search started elsewhere (e.g. a tag).
    _controller = TextEditingController(
      text: ref.read(searchNotifierProvider).keyword,
    );
    _controller.addListener(_refresh);
    _focusNode.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    ref.read(searchNotifierProvider.notifier).search(value ?? _controller.text);
  }

  void _searchFor(String keyword) {
    _controller.text = keyword;
    _focusNode.unfocus();
    _submit(keyword);
  }

  void _cancel() {
    _controller.clear();
    _focusNode.unfocus();
    ref.read(searchNotifierProvider.notifier).clear();
  }

  void _selectScope(int index) {
    ref
        .read(searchNotifierProvider.notifier)
        .selectScope(SearchScope.values[index]);
  }

  void _openPost(Object id) {
    final callback = widget.onOpenPost;
    callback == null ? context.push(AppRoutes.postDetail(id)) : callback(id);
  }

  void _openUser(Object id) {
    final callback = widget.onOpenUser;
    callback == null ? context.push(AppRoutes.userProfile(id)) : callback(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    ref.listen<String>(
      searchNotifierProvider.select((state) => state.keyword),
      (previous, next) {
        if (next.isNotEmpty && next != _controller.text.trim()) {
          _controller.text = next;
        }
      },
    );
    final showCancel =
        _focusNode.hasFocus ||
        _controller.text.isNotEmpty ||
        state.phase != SearchPhase.idle;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            AppTheme.space2,
            AppTheme.space2,
            AppTheme.space1,
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: '搜索词',
                  child: FTextField(
                    control: FTextFieldControl.managed(controller: _controller),
                    focusNode: _focusNode,
                    hint: '搜索帖子、用户或标签',
                    textInputAction: TextInputAction.search,
                    onSubmit: _submit,
                    clearable: (value) => value.text.isNotEmpty,
                    prefixBuilder: (context, style, variants) =>
                        FTextField.prefixIconBuilder(
                          context,
                          style,
                          variants,
                          const Icon(FLucideIcons.search),
                        ),
                  ),
                ),
              ),
              if (showCancel)
                FButton(
                  key: const Key('search-cancel'),
                  variant: FButtonVariant.ghost,
                  size: FButtonSizeVariant.sm,
                  mainAxisSize: MainAxisSize.min,
                  onPress: _cancel,
                  child: const Text('取消'),
                )
              else
                const SizedBox(width: AppTheme.space2),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.pageInset),
          child: FTabs(
            control: FTabControl.lifted(
              index: state.scope.index,
              onChange: _selectScope,
            ),
            children: const [
              FTabEntry(label: Text('综合'), child: SizedBox.shrink()),
              FTabEntry(label: Text('用户'), child: SizedBox.shrink()),
              FTabEntry(label: Text('标签'), child: SizedBox.shrink()),
            ],
          ),
        ),
        Expanded(child: _buildBody(state)),
      ],
    );
  }

  Widget _buildIdle(SearchState state) {
    final theme = context.theme;
    if (state.recentKeywords.isEmpty) {
      return const EmptyView(message: '搜索帖子、用户和标签', icon: FLucideIcons.search);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.pageInset,
        AppTheme.space4,
        AppTheme.pageInset,
        AppTheme.space6,
      ),
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  '最近搜索',
                  style: theme.typography.body.md.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            FButton(
              key: const Key('search-clear-recent'),
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.xs,
              mainAxisSize: MainAxisSize.min,
              onPress: ref.read(searchNotifierProvider.notifier).clearRecent,
              child: const Text('清空'),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.space2),
        Wrap(
          spacing: AppTheme.space2,
          runSpacing: AppTheme.space2,
          children: [
            for (final keyword in state.recentKeywords)
              FButton(
                variant: FButtonVariant.secondary,
                size: FButtonSizeVariant.sm,
                mainAxisSize: MainAxisSize.min,
                prefix: const Icon(FLucideIcons.history, size: 14),
                onPress: () => _searchFor(keyword),
                child: Text(keyword),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBody(SearchState state) {
    return switch (state.phase) {
      SearchPhase.idle => _buildIdle(state),
      SearchPhase.loading => const LoadingView(),
      SearchPhase.failure => ErrorView(
        message: state.error ?? '搜索失败',
        onRetry: state.keyword.isEmpty
            ? null
            : ref.read(searchNotifierProvider.notifier).retry,
      ),
      SearchPhase.success => Column(
        children: [
          if (state.results.degraded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: FAlert(
                title: const Text('部分结果暂不可用'),
                subtitle: Text(
                  state.results.unavailableTypes.isEmpty
                      ? '搜索已降级，部分类型未能返回'
                      : '暂不可用：${state.results.unavailableTypes.join('、')}',
                ),
              ),
            ),
          Expanded(
            child: state.results.isEmpty
                ? EmptyView(
                    message: _emptySearchMessage(state.results),
                    icon: FLucideIcons.searchX,
                  )
                : _SearchResultList(
                    results: state.results,
                    scope: state.scope,
                    hasMore: state.hasMore,
                    isLoadingMore: state.isLoadingMore,
                    loadMoreError: state.error,
                    onLoadMore: ref
                        .read(searchNotifierProvider.notifier)
                        .loadMore,
                    onOpenPost: _openPost,
                    onOpenUser: _openUser,
                    keyword: state.keyword,
                    onSearchTag: _searchFor,
                  ),
          ),
        ],
      ),
    };
  }

  String _emptySearchMessage(SearchResults results) {
    final unavailable = {
      for (final type in results.unavailableTypes) type.toLowerCase(),
    };
    if (unavailable.contains('post') || unavailable.contains('posts')) {
      return '帖子搜索暂不可用';
    }
    return '没有找到相关结果';
  }
}

class _SearchResultList extends StatelessWidget {
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

  const _SearchResultList({
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
    if (results.posts.isNotEmpty) {
      children.add(_sectionTitle(context, '帖子'));
      children.addAll(results.posts.map((post) => _post(context, post)));
    }
    if (results.users.isNotEmpty) {
      children.add(
        _sectionTitle(context, scope == SearchScope.users ? '用户' : '相关用户'),
      );
      children.addAll(results.users.map(_user));
    }
    if (results.tags.isNotEmpty) {
      children.add(
        _sectionTitle(context, scope == SearchScope.tags ? '标签' : '相关标签'),
      );
      children.addAll(results.tags.map((tag) => _tag(context, tag)));
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

  Widget _sectionTitle(BuildContext context, String label) {
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

  Widget _post(BuildContext context, SearchPostResult post) {
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

  Widget _user(SearchUserResult user) {
    return FItem(
      prefix: CachedAvatar(
        url: user.avatarUrl,
        name: user.displayName,
        radius: 20,
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        user.bio.isEmpty ? '@${user.username}' : user.bio,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      details: Text('${user.followerCount} 关注者'),
      suffix: const Icon(FLucideIcons.chevronRight),
      onPress: () => onOpenUser(user.id),
    );
  }

  // A plain row keeps tags on the same 16px inset as post results.
  Widget _tag(BuildContext context, SearchTagResult tag) {
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
