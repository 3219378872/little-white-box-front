import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class SkeletonLoader extends StatelessWidget {
  final Widget child;

  const SkeletonLoader({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      highlightColor: Theme.of(context).colorScheme.surface,
      child: child,
    );
  }
}

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonLoader(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(radius: 16),
                    const SizedBox(width: 8),
                    Container(width: 80, height: 14, color: Colors.white),
                    const Spacer(),
                    Container(width: 40, height: 12, color: Colors.white),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                    width: double.infinity, height: 16, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 200, height: 14, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 160, height: 14, color: Colors.white),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 40, height: 12, color: Colors.white),
                    const SizedBox(width: 16),
                    Container(width: 40, height: 12, color: Colors.white),
                    const SizedBox(width: 16),
                    Container(width: 40, height: 12, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
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
      itemBuilder: (_, __) => const PostCardSkeleton(),
    );
  }
}
