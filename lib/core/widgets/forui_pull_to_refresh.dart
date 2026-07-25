import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

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

class _ForuiPullToRefreshState extends State<ForuiPullToRefresh> {
  static const _indicatorExtent = 52.0;
  double _dragOffset = 0;
  bool _refreshing = false;

  double get _progress =>
      (_dragOffset / widget.triggerDistance).clamp(0.0, 1.0);

  bool _handleNotification(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) {
      return false;
    }

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

  void _setDragOffset(double value) {
    final next = value.clamp(0.0, widget.triggerDistance * 1.5);
    if (next == _dragOffset || !mounted) return;
    setState(() => _dragOffset = next);
  }

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
