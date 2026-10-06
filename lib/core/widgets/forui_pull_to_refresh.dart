import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 以 Forui 样式实现的下拉刷新：监听子滚动视图的顶部越界拖动，
/// 拖过 [triggerDistance] 松手后执行 [onRefresh]，期间显示进度圈。
///
/// 子视图需使用 `AlwaysScrollableScrollPhysics`，内容不足一屏时也能下拉。
class ForuiPullToRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  final double triggerDistance;

  const ForuiPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.triggerDistance = 72,
  });

  @override
  State<ForuiPullToRefresh> createState() => _ForuiPullToRefreshState();
}

// 用 [_dragOffset] 记录下拉距离驱动指示器，刷新期间锁定不再响应拖动。
class _ForuiPullToRefreshState extends State<ForuiPullToRefresh> {
  static const _indicatorExtent = 52.0;
  double _dragOffset = 0;
  bool _refreshing = false;

  double get _progress =>
      (_dragOffset / widget.triggerDistance).clamp(0.0, 1.0);

  // 只处理直接子级的纵向滚动；返回 false 让通知继续向上冒泡。
  bool _handleNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

    // 新一轮拖动清零；越界拖动（钳制型 physics 发 Overscroll，弹性 physics 发
    // 负 pixels 的 Update）按一半阻尼累加；松手时达到阈值才刷新，否则回弹。
    if (notification is ScrollStartNotification && !_refreshing) {
      _setDragOffset(0);
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null &&
        notification.overscroll < 0 &&
        !_refreshing) {
      _setDragOffset(_dragOffset - notification.overscroll * 0.5);
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null &&
        notification.metrics.pixels < notification.metrics.minScrollExtent &&
        !_refreshing) {
      final overscroll =
          notification.metrics.minScrollExtent - notification.metrics.pixels;
      _setDragOffset(math.max(_dragOffset, overscroll * 0.5));
    } else if (notification is ScrollEndNotification && !_refreshing) {
      if (_dragOffset >= widget.triggerDistance) {
        _refresh();
      } else {
        _setDragOffset(0);
      }
    }
    return false;
  }

  // 限制在阈值的 1.5 倍内，值不变时跳过重建。
  void _setDragOffset(double value) {
    final next = value.clamp(0.0, widget.triggerDistance * 1.5);
    if (next == _dragOffset || !mounted) return;
    setState(() => _dragOffset = next);
  }

  // 刷新期间把指示器停在阈值位置，结束后（含失败）复位。
  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _dragOffset = widget.triggerDistance;
    });
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
          _dragOffset = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final visible = _refreshing || _dragOffset > 0;
    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: _handleNotification,
          child: widget.child,
        ),
        // 顶部浮层指示器：下拉时箭头随进度旋转、到阈值变主色，刷新时换成进度圈。
        PositionedDirectional(
          top: 8,
          start: 0,
          end: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border),
                  ),
                  child: SizedBox.square(
                    dimension: _indicatorExtent,
                    child: Center(
                      child: _refreshing
                          ? const FCircularProgress(size: .sm)
                          : Transform.rotate(
                              angle: _progress * math.pi,
                              child: Icon(
                                FLucideIcons.arrowDown,
                                size: 18,
                                color: _progress == 1
                                    ? colors.primary
                                    : colors.mutedForeground,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
