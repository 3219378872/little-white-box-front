import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../search/application/search_notifier.dart';
import '../../application/trending_tags.dart';

/// Desktop-only right column next to the feed: compose entry, Agent entry and
/// tags ranked from the already loaded recommend feed.
class FeedSideRail extends ConsumerWidget {
  const FeedSideRail({super.key});

  void _requireLogin(BuildContext context, WidgetRef ref, String location) {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    context.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final tags = ref.watch(trendingTagsProvider);
    return ListView(
      primary: false,
      padding: const EdgeInsets.only(
        top: AppTheme.space4,
        bottom: AppTheme.space6,
      ),
      children: [
        FButton(
          key: const Key('feed-rail-compose'),
          prefix: const Icon(FLucideIcons.squarePen),
          onPress: () => _requireLogin(context, ref, '/post/new'),
          child: const Text('发布帖子'),
        ),
        const SizedBox(height: AppTheme.space4),
        _RailSection(
          icon: FLucideIcons.sparkles,
          title: '小白盒 Agent',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '让 Agent 帮你检索、比较社区里的讨论，并附上原帖出处。',
                style: theme.typography.body.sm.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              FButton(
                key: const Key('feed-rail-agent'),
                variant: FButtonVariant.outline,
                size: FButtonSizeVariant.sm,
                onPress: () =>
                    _requireLogin(context, ref, '/messages/assistant'),
                // Accent text keeps the outline action from reading as
                // disabled on the muted rail card.
                child: Text(
                  '开始对话',
                  style: TextStyle(
                    color: theme.colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space4),
          _RailSection(
            icon: FLucideIcons.hash,
            title: '热门标签',
            caption: '按当前推荐内容统计',
            child: Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space2,
              children: [
                for (final tag in tags)
                  _TagChip(
                    tag: tag,
                    onPress: () {
                      ref
                          .read(searchNotifierProvider.notifier)
                          .search(tag.name);
                      context.go('/search');
                    },
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? caption;
  final Widget child;

  const _RailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.muted,
        borderRadius: AppTheme.cardRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: theme.colors.primary),
                const SizedBox(width: AppTheme.space2),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.typography.body.md.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
            const SizedBox(height: AppTheme.space3),
            child,
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final TrendingTag tag;
  final VoidCallback onPress;

  const _TagChip({required this.tag, required this.onPress});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FTappable(
      onPress: onPress,
      semanticsLabel: '搜索标签 ${tag.name}，${tag.postCount} 篇帖子',
      builder: (context, variants, _) {
        final hovered =
            variants.contains(FTappableVariant.hovered) ||
            variants.contains(FTappableVariant.pressed);
        return DecoratedBox(
          decoration: BoxDecoration(
            color: hovered
                ? AppTheme.accentSoft(theme.colors)
                : theme.colors.background,
            borderRadius: AppTheme.controlRadius,
            border: Border.all(color: theme.colors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '# ${tag.name}'),
                  TextSpan(
                    text: '  ${tag.postCount}',
                    style: TextStyle(color: theme.colors.mutedForeground),
                  ),
                ],
              ),
              style: theme.typography.body.sm.copyWith(
                color: hovered ? theme.colors.primary : theme.colors.foreground,
              ),
            ),
          ),
        );
      },
    );
  }
}
