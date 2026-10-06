import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/search_notifier.dart';
import '../data/search_models.dart';
import 'widgets/search_result_list.dart';
import '../../../core/router/app_routes.dart';

/// 搜索页：搜索框、范围标签与按阶段（空闲/加载/失败/成功）切换的结果区。
///
/// 传入 [onOpenPost]/[onOpenUser] 可接管结果导航（测试用），否则默认 push 详情路由。
class SearchPage extends ConsumerStatefulWidget {
  final ValueChanged<Object>? onOpenPost;
  final ValueChanged<Object>? onOpenUser;

  const SearchPage({super.key, this.onOpenPost, this.onOpenUser});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

// 持有搜索框控制器与焦点，把输入事件转交给 SearchNotifier。
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

  // 输入或焦点变化时重建，以更新「取消」按钮的显隐。
  void _refresh() => setState(() {});

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // 提交搜索：键盘提交传入当前值，其他入口读取输入框文本。
  void _submit([String? value]) {
    ref.read(searchNotifierProvider.notifier).search(value ?? _controller.text);
  }

  // 点最近搜索或标签：回填输入框、收起键盘后直接搜索。
  void _searchFor(String keyword) {
    _controller.text = keyword;
    _focusNode.unfocus();
    _submit(keyword);
  }

  // 取消：清空输入、收起键盘并回到空闲页。
  void _cancel() {
    _controller.clear();
    _focusNode.unfocus();
    ref.read(searchNotifierProvider.notifier).clear();
  }

  // 标签页下标与 SearchScope 枚举顺序一致。
  void _selectScope(int index) {
    ref
        .read(searchNotifierProvider.notifier)
        .selectScope(SearchScope.values[index]);
  }

  // 打开帖子详情；测试注入回调时不走路由。
  void _openPost(Object id) {
    final callback = widget.onOpenPost;
    callback == null ? context.push(AppRoutes.postDetail(id)) : callback(id);
  }

  // 打开用户主页；测试注入回调时不走路由。
  void _openUser(Object id) {
    final callback = widget.onOpenUser;
    callback == null ? context.push(AppRoutes.userProfile(id)) : callback(id);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchNotifierProvider);
    // 关键词由别处改写（如点标签再搜）时同步回输入框；与输入框去空白后相同则不覆盖。
    ref.listen<String>(
      searchNotifierProvider.select((state) => state.keyword),
      (previous, next) {
        if (next.isNotEmpty && next != _controller.text.trim()) {
          _controller.text = next;
        }
      },
    );
    // 有焦点、有输入或已离开空闲态时才显示「取消」，否则留出右侧间距。
    final showCancel =
        _focusNode.hasFocus ||
        _controller.text.isNotEmpty ||
        state.phase != SearchPhase.idle;
    return Column(
      children: [
        // 顶部搜索栏：输入框 + 取消按钮。
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
        // 范围标签页：只用作切换器，内容统一由下方结果区渲染。
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
        // 结果区随搜索阶段切换。
        Expanded(child: _buildBody(state)),
      ],
    );
  }

  // 空闲态：有最近搜索时展示可点击的历史关键词，否则给引导空态。
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
        // 标题行：「最近搜索」与清空按钮。
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
        // 历史关键词按钮，点击即重搜。
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

  // 结果区按搜索阶段切换；成功态在降级时先给横幅再列结果。
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
          // 降级横幅：列出未能返回的结果类型。
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
            // 零命中给空态，否则交给结果列表（含加载更多）。
            child: state.results.isEmpty
                ? EmptyView(
                    message: _emptySearchMessage(state.results),
                    icon: FLucideIcons.searchX,
                  )
                : SearchResultList(
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

  // 零命中文案：帖子类型不可用时说明原因，而不是笼统的「没有结果」。
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
