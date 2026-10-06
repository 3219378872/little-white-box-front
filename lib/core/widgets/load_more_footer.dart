import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../theme/app_theme.dart';
import 'loading_view.dart';

/// 分页列表尾部的「加载更多」状态，供信息流、评论、个人帖子、广告与搜索结果共用。
///
/// 按优先级只展示一种状态：加载中 → 失败提示与重试 → 手动「加载更多」按钮 →
/// 「没有更多了」→ 空。滚动自动翻页的列表不传 [onLoadMore]；需要用户点击翻页的
/// 列表传入 [onLoadMore]，按钮仅在可继续加载时由调用方挂出。
class LoadMoreFooter extends StatelessWidget {
  /// 下一页请求进行中。
  final bool isLoading;

  /// 非空时展示该错误文案与「重试」按钮。
  final String? error;

  /// 失败后的重试动作；为空时回退到 [onLoadMore]。
  final VoidCallback? onRetry;

  /// 手动翻页列表的加载动作；为空表示由滚动自动触发。
  final VoidCallback? onLoadMore;

  /// 已到底时是否展示「没有更多了」。
  final bool showEnd;

  const LoadMoreFooter({
    super.key,
    required this.isLoading,
    this.error,
    this.onRetry,
    this.onLoadMore,
    this.showEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // 加载中：与首屏一致的居中进度圈。
    if (isLoading) {
      return const Padding(padding: EdgeInsets.all(16), child: LoadingView());
    }
    // 失败：说明原因并允许原地重试，不随滚动反复重发。
    final error = this.error;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            FButton(
              variant: FButtonVariant.secondary,
              onPress: onRetry ?? onLoadMore,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }
    // 手动翻页：空闲时给出显式按钮。
    final loadMore = onLoadMore;
    if (loadMore != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.space3),
        child: FButton(
          variant: FButtonVariant.outline,
          onPress: loadMore,
          child: const Text('加载更多'),
        ),
      );
    }
    // 到底：弱化的结束提示。
    if (showEnd) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            '— 没有更多了 —',
            style: TextStyle(color: theme.colors.mutedForeground, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
