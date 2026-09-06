import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../application/search_notifier.dart';
import '../data/search_models.dart';

class SearchPage extends ConsumerStatefulWidget {
  final ValueChanged<Object>? onOpenPost;
  final ValueChanged<Object>? onOpenUser;

  const SearchPage({super.key, this.onOpenPost, this.onOpenUser});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? value]) {
    ref.read(searchNotifierProvider.notifier).search(value ?? _controller.text);
  }

  void _selectScope(int index) {
    ref
        .read(searchNotifierProvider.notifier)
        .selectScope(SearchScope.values[index]);
  }

  void _openPost(Object id) {
    final callback = widget.onOpenPost;
    callback == null ? context.push('/post/${jsonInt64Id(id)}') : callback(id);
  }

  void _openUser(Object id) {
    final callback = widget.onOpenUser;
    callback == null ? context.push('/user/${jsonInt64Id(id)}') : callback(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  label: '搜索词',
                  child: FTextField(
                    control: FTextFieldControl.managed(controller: _controller),
                    hint: '搜索内容',
                    textInputAction: TextInputAction.search,
                    onSubmit: _submit,
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
              const SizedBox(width: 8),
              FButton.icon(
                key: const Key('search-submit'),
                onPress: state.phase == SearchPhase.loading ? null : _submit,
                child: const Icon(FLucideIcons.search, semanticLabel: '搜索'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
        const SizedBox(height: 8),
        Expanded(child: _buildBody(state)),
      ],
    );
  }

  Widget _buildBody(SearchState state) {
    return switch (state.phase) {
      SearchPhase.idle => const SizedBox.shrink(),
      SearchPhase.loading => const Center(child: FCircularProgress()),
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
                    onOpenPost: _openPost,
                    onOpenUser: _openUser,
                    onSearchTag: (tag) {
                      _controller.text = tag;
                      _submit(tag);
                    },
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
  final ValueChanged<Object> onOpenPost;
  final ValueChanged<Object> onOpenUser;
  final ValueChanged<String> onSearchTag;

  const _SearchResultList({
    required this.results,
    required this.scope,
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
      children.addAll(results.tags.map(_tag));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: children,
    );
  }

  Widget _sectionTitle(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        label,
        style: context.theme.typography.body.lg.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _post(BuildContext context, SearchPostResult post) {
    final highlight = post.contentHighlight
        .replaceAll(RegExp(r'</?em>', caseSensitive: false), '')
        .trim();
    final avatar = CachedAvatar(
      url: post.authorAvatar,
      name: post.displayAuthor,
      radius: 10,
    );
    final theme = context.theme;
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
            Text(
              post.title.isEmpty ? '未命名帖子' : post.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.typography.body.lg.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (highlight.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                highlight,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.md,
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

  Widget _tag(SearchTagResult tag) {
    return FItem(
      prefix: const Icon(FLucideIcons.hash),
      title: Text(tag.name),
      details: Text('${tag.postCount} 篇帖子'),
      suffix: const Icon(FLucideIcons.search),
      onPress: () => onSearchTag(tag.name),
    );
  }
}
