import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_notifier.dart';
import '../../../review/application/reviewer_access.dart';
import '../../../search/application/search_notifier.dart';
import '../../application/trending_tags.dart';
import '../../../../core/router/app_routes.dart';

/// Desktop-only right column next to the feed: compose entry, Agent entry and
/// tags ranked from the already loaded recommend feed.
class FeedSideRail extends ConsumerWidget {
  const FeedSideRail({super.key});

  // Sends anonymous users to login instead of a page that needs an account.
  void _requireLogin(BuildContext context, WidgetRef ref, String location) {
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    context.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final tags = ref.watch(trendingTagsProvider);
    final authenticated = ref.watch(
      authNotifierProvider.select((state) => state.isAuthenticated),
    );
    final canReview = ref.watch(canReviewProvider);
    return ListView(
      primary: false,
      padding: const EdgeInsets.only(
        top: AppTheme.space4,
        bottom: AppTheme.space6,
      ),
      children: [
        // Compose entry.
        FButton(
          key: const Key('feed-rail-compose'),
          prefix: const Icon(FLucideIcons.squarePen),
          onPress: () => _requireLogin(context, ref, AppRoutes.postNew),
          child: const Text('发布帖子'),
        ),
        const SizedBox(height: AppTheme.space4),
        // Agent entry with a one-line pitch.
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
                onPress: () => _requireLogin(context, ref, AppRoutes.assistant),
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
        // Business tools for signed-in users; review only for reviewer roles.
        if (authenticated) ...[
          const SizedBox(height: AppTheme.space4),
          _RailSection(
            icon: FLucideIcons.briefcaseBusiness,
            title: '商业',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppTheme.space2,
              children: [
                FButton(
                  key: const Key('feed-rail-ads'),
                  variant: FButtonVariant.outline,
                  size: FButtonSizeVariant.sm,
                  prefix: const Icon(FLucideIcons.megaphone),
                  onPress: () => context.push(AppRoutes.ads),
                  child: const Text('广告主控制台'),
                ),
                if (canReview)
                  FButton(
                    key: const Key('feed-rail-review'),
                    variant: FButtonVariant.outline,
                    size: FButtonSizeVariant.sm,
                    prefix: const Icon(FLucideIcons.clipboardCheck),
                    onPress: () => context.push(AppRoutes.review),
                    child: const Text('审核工作台'),
                  ),
              ],
            ),
          ),
        ],
        // Trending tags; tapping one runs a search for it and opens the search tab.
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
                      context.go(AppRoutes.search);
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

// Muted card with an icon header, optional caption and body.
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

// Outlined tag chip showing the tag name and its loaded post count.
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
