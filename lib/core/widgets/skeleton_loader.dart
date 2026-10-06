import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

/// 骨架屏容器：把 [child] 的所有像素统一染成在次要色与背景色之间往返的闪烁色，
/// 子组件只需摆出占位形状。
class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

// 驱动闪烁动画；系统关闭动画时停在静态色。
class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) => ColorFiltered(
        colorFilter: ColorFilter.mode(
          Color.lerp(colors.secondary, colors.background, _controller.value)!,
          BlendMode.srcIn,
        ),
        child: child,
      ),
    );
  }
}

/// 与帖子卡片布局对应的单条骨架（作者行、标题、摘要、互动计数）。
class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FAvatar.raw(size: 20),
                const SizedBox(width: 8),
                Container(
                  width: 80,
                  height: 14,
                  color: const Color(0xFFFFFFFF),
                ),
                const Spacer(),
                Container(
                  width: 40,
                  height: 12,
                  color: const Color(0xFFFFFFFF),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              height: 16,
              color: const Color(0xFFFFFFFF),
            ),
            const SizedBox(height: 8),
            Container(width: 200, height: 14, color: const Color(0xFFFFFFFF)),
            const SizedBox(height: 8),
            Container(width: 160, height: 14, color: const Color(0xFFFFFFFF)),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 12,
                  color: const Color(0xFFFFFFFF),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 12,
                  color: const Color(0xFFFFFFFF),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 40,
                  height: 12,
                  color: const Color(0xFFFFFFFF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Feed 首屏加载时展示的若干条帖子骨架。
class PostCardSkeletonList extends StatelessWidget {
  final int count;
  const PostCardSkeletonList({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: count,
      itemBuilder: (_, _) => const PostCardSkeleton(),
    );
  }
}
