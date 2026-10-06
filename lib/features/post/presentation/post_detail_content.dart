import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../../profile/application/follow_controller.dart';
import '../../profile/application/user_profile_providers.dart';

/// 帖子详情正文区：标题、作者行、正文、配图、标签，以及与评论区之间的分隔带和排序栏。
///
/// 排序与关注等写操作由详情页通过回调注入，本组件只负责排版。
class PostDetailArticle extends StatelessWidget {
  final GetPostResp post;

  /// 当前评论排序（1 最新、2 最热），用于高亮排序栏。
  final int commentSortBy;
  final ValueChanged<int> onSelectSort;

  /// 切换关注；参数是点击时界面展示的关注态。
  final ValueChanged<bool> onToggleFollow;

  const PostDetailArticle({
    super.key,
    required this.post,
    required this.commentSortBy,
    required this.onSelectSort,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            AppTheme.space2,
            AppTheme.pageInset,
            AppTheme.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (post.title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.space4),
                  child: Semantics(
                    header: true,
                    child: Text(post.title, style: theme.typography.display.md),
                  ),
                ),
              PostAuthorRow(post: post, onToggleFollow: onToggleFollow),
              const SizedBox(height: AppTheme.space4),
              Text(
                post.content,
                style: theme.typography.body.md.copyWith(height: 1.75),
              ),
              if (post.images.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space4),
                ...post.images.map(
                  (url) => Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.space2),
                    child: ClipRRect(
                      borderRadius: AppTheme.imageRadius,
                      child: CachedNetworkImage(
                        imageUrl: url,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                      ),
                    ),
                  ),
                ),
              ],
              if (post.tags.isNotEmpty) ...[
                const SizedBox(height: AppTheme.space3),
                Wrap(
                  spacing: AppTheme.space2,
                  runSpacing: AppTheme.space2,
                  children: post.tags
                      .map((tag) => AppTagBadge(label: tag))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        // Section band between the article and the discussion.
        SizedBox(height: 8, child: ColoredBox(color: theme.colors.muted)),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.pageInset,
            AppTheme.space3,
            AppTheme.pageInset,
            AppTheme.space1,
          ),
          child: _CommentSortBar(
            commentCount: post.commentCount.toInt(),
            sortBy: commentSortBy,
            onSelectSort: onSelectSort,
          ),
        ),
      ],
    );
  }
}

/// 作者行：头像、昵称、发布时间与浏览数（点击进入作者主页），非本人帖子时附关注按钮。
///
/// 关注态来自共享的 follow controller 与用户关注 provider，故自行订阅；
/// 点击关注的登录拦截、错误提示仍由页面回调处理。
class PostAuthorRow extends ConsumerWidget {
  final GetPostResp post;
  final ValueChanged<bool> onToggleFollow;

  const PostAuthorRow({
    super.key,
    required this.post,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final auth = ref.watch(authNotifierProvider);
    final authorKey = jsonInt64Id(post.authorId);
    // 已登录且作者 ID 与当前用户一致即本人帖子，不展示关注按钮。
    final own =
        jsonInt64IsPositive(auth.userId) &&
        authorKey == jsonInt64Id(auth.userId);
    // 关注态未读到前（null）禁用按钮，避免基于猜测的值发出反向请求。
    final following = auth.isAuthenticated && !own
        ? ref.watch(userFollowingProvider(authorKey)).value
        : false;
    final follow = ref.watch(followControllerProvider(authorKey));
    final isFollowing = follow.following ?? following ?? false;
    return Row(
      children: [
        Expanded(
          child: FTappable(
            onPress: () => context.push(AppRoutes.userProfile(post.authorId)),
            child: Row(
              children: [
                CachedAvatar(
                  url: post.authorAvatar,
                  name: post.authorName,
                  radius: 20,
                ),
                const SizedBox(width: AppTheme.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.md.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${formatRelativeTime(post.createdAt, includeYear: true)}'
                        '  ·  ${post.viewCount} 次浏览',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.xs.copyWith(
                          color: theme.colors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!own) ...[
          const SizedBox(width: AppTheme.space2),
          FButton(
            key: const Key('post-follow-author'),
            size: FButtonSizeVariant.sm,
            mainAxisSize: MainAxisSize.min,
            variant: isFollowing
                ? FButtonVariant.secondary
                : FButtonVariant.primary,
            prefix: Icon(
              isFollowing ? FLucideIcons.check : FLucideIcons.plus,
              size: 16,
            ),
            onPress:
                follow.isBusy || (auth.isAuthenticated && following == null)
                ? null
                : () => onToggleFollow(isFollowing),
            child: Text(isFollowing ? '已关注' : '关注'),
          ),
        ],
      ],
    );
  }
}

// 评论区标题（含评论数）与「最新/最热」排序切换。
class _CommentSortBar extends StatelessWidget {
  final int commentCount;
  final int sortBy;
  final ValueChanged<int> onSelectSort;

  const _CommentSortBar({
    required this.commentCount,
    required this.sortBy,
    required this.onSelectSort,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: '评论'),
                if (commentCount > 0)
                  TextSpan(
                    text: '  $commentCount',
                    style: TextStyle(color: theme.colors.mutedForeground),
                  ),
              ],
            ),
            style: theme.typography.body.lg.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Spacer(),
        for (final (sort, label) in const [(1, '最新'), (2, '最热')])
          _CommentSortChip(
            key: ValueKey('comment-sort-$sort'),
            label: label,
            selected: sortBy == sort,
            onPress: () => onSelectSort(sort),
          ),
      ],
    );
  }
}

/// Comment sort toggle; the active order uses the accent like other
/// selected navigation so it does not read as a disabled control.
class _CommentSortChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onPress;

  const _CommentSortChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    // One merged node: a button that reports its selected state. The notifier
    // ignores re-selecting the active order, so the chip is never disabled.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: '按$label排序',
      onTap: onPress,
      excludeSemantics: true,
      child: FTappable(
        onPress: onPress,
        builder: (context, variants, _) {
          final hovered =
              !selected &&
              (variants.contains(FTappableVariant.hovered) ||
                  variants.contains(FTappableVariant.pressed));
          return Container(
            constraints: const BoxConstraints(minHeight: 32, minWidth: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.space3),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.accentSoft(colors)
                  : hovered
                  ? colors.secondary
                  : null,
              borderRadius: AppTheme.controlRadius,
            ),
            child: Text(
              label,
              style: theme.typography.body.sm.copyWith(
                color: selected ? colors.primary : colors.mutedForeground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }
}
