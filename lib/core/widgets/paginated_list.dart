import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../api/api_exceptions.dart';
import 'error_view.dart';import 'forui_pull_to_refresh.dart';

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
    if (widget.isLoading && widget.items.isEmpty) {
      return const Center(child: FCircularProgress());
    }

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

    final showTail = widget.hasMore ||
        widget.isLoadingMore ||
        (widget.error != null);
    return ForuiPullToRefresh(
      onRefresh: () async => widget.onRefresh(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: widget.items.length + (showTail ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.items.length) {
            if (widget.isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: FCircularProgress()),
              );
            }
            if (widget.error != null) {
              final theme = context.theme;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    Text(
                      friendlyErrorMessage(widget.error!),
                      textAlign: TextAlign.center,
                      style: theme.typography.body.sm.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    FButton(
                      variant: FButtonVariant.secondary,
                      onPress: widget.onLoadMore,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              );
            }
            if (widget.hasMore) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: FCircularProgress()),
              );
            }
          }
          return widget.itemBuilder(context, widget.items[index]);
        },
      ),
    );
  }
}
