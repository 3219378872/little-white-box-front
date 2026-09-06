import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class SkeletonLoader extends StatefulWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

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
