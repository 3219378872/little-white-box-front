import 'package:flutter/widgets.dart';

import '../api/api_exceptions.dart';
import 'error_view.dart';
import 'forui_pull_to_refresh.dart';
import 'load_more_footer.dart';
import 'loading_view.dart';

/// 通用的下拉刷新 + 滚动到底自动翻页列表，首屏加载、空态、错误态与尾部状态都由它处理；
/// 数据与分页状态由调用方的 notifier 持有，本组件只负责展示与触发回调。
class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final VoidCallback onLoadMore;
  final VoidCallback onRefresh;
  final Widget? emptyWidget;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.hasMore,
    required this.isLoading,
    required this.isLoadingMore,
    this.error,
    required this.itemBuilder,
    required this.onLoadMore,
    required this.onRefresh,
    this.emptyWidget,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

// 持有滚动控制器，接近底部时触发 [PaginatedListView.onLoadMore]。
class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 距底部 200px 内请求下一页；重复触发的去重由调用方负责。
  void _onScroll() {
    // 加载更多失败后停在原地等待用户点重试，不随滚动反复重发同一游标。
    if (widget.error != null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 首屏加载中。
    if (widget.isLoading && widget.items.isEmpty) {
      return const LoadingView();
    }

    // 无数据：首屏失败给整页错误态，否则给可下拉刷新的空态。
    if (widget.items.isEmpty) {
      if (widget.error != null) {
        return ErrorView(message: widget.error!, onRetry: widget.onRefresh);
      }
      return ForuiPullToRefresh(
        onRefresh: () async => widget.onRefresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: widget.emptyWidget ?? const Center(child: Text('暂无内容')),
            ),
          ],
        ),
      );
    }

    // 有数据：列表 + 尾部状态行（仍有下一页、加载中或翻页失败时出现）。
    final showTail =
        widget.hasMore || widget.isLoadingMore || (widget.error != null);
    return ForuiPullToRefresh(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: widget.items.length + (showTail ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            // 尾部：加载中或仍有下一页时转圈，失败时原地重试。
            final error = widget.error;
            return LoadMoreFooter(
              isLoading:
                  widget.isLoadingMore || (error == null && widget.hasMore),
              error: error == null ? null : friendlyErrorMessage(error),
              onRetry: widget.onLoadMore,
            );
          }
          return widget.itemBuilder(context, widget.items[index]);
        },
      ),
    );
  }
}
