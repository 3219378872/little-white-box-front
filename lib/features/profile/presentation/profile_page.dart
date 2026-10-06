import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../../review/application/reviewer_access.dart';
import '../application/user_posts_notifier.dart';
import 'widgets/user_post_list.dart';
import '../application/profile_dependencies.dart';

final _userProfileProvider = FutureProvider.autoDispose
    .family<GetUserResp, String>((ref, userId) {
      ref.watch(authSessionIdentityProvider);
      return ref.read(userRepositoryProvider).getUserProfile(userId);
    });

class ProfilePage extends ConsumerWidget {
  final Object? userId;
  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final targetUserId = userId ?? auth.userId;

    if (!jsonInt64IsPositive(targetUserId)) {
      return FScaffold(
        header: const FHeader(title: Text('个人中心')),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请先登录'),
              const SizedBox(height: 16),
              FButton(
                onPress: () => context.push('/auth/login'),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    final isOwnProfile =
        userId == null || jsonInt64Id(userId) == jsonInt64Id(auth.userId);

    return _ProfileContent(
      key: ValueKey('${auth.sessionRevision}:${jsonInt64Id(targetUserId)}'),
      userId: jsonInt64Id(targetUserId),
      isOwnProfile: isOwnProfile,
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const _ProfileContent({
    super.key,
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  bool? _followOverride;
  bool _followBusy = false;
  bool? _personalizationEnabled;
  bool _personalizationBusy = false;
  int _tabIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    if (widget.isOwnProfile) {
      _loadPersonalization();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _handlePageChanged(int index) {
    if (index != _tabIndex) {
      setState(() => _tabIndex = index);
    }
  }

  Future<void> _loadPersonalization() async {
    try {
      final preference = await ref
          .read(personalizationRepositoryProvider)
          .getPreference();
      if (!mounted) return;
      setState(() => _personalizationEnabled = preference.enabled);
    } catch (_) {
      if (!mounted) return;
      setState(() => _personalizationEnabled = null);
    }
  }

  Future<void> _setPersonalization(bool enabled) async {
    if (_personalizationBusy) return;
    final previous = _personalizationEnabled;
    setState(() {
      _personalizationEnabled = enabled;
      _personalizationBusy = true;
    });
    try {
      await ref
          .read(personalizationRepositoryProvider)
          .setPreference(enabled: enabled);
    } catch (e) {
      if (!mounted) return;
      setState(() => _personalizationEnabled = previous);
      showAppError(context, '个性化设置失败: ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _personalizationBusy = false);
    }
  }

  Future<void> _toggleFollow(bool isFollowing) async {
    if (_followBusy) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push('/auth/login');
      return;
    }
    final repo = ref.read(userRepositoryProvider);
    final previousOverride = _followOverride;
    setState(() {
      _followOverride = !isFollowing;
      _followBusy = true;
    });
    try {
      if (isFollowing) {
        await repo.unfollowUser(widget.userId);
      } else {
        await repo.followUser(widget.userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _followOverride = previousOverride);
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(_userProfileProvider(widget.userId));
    final theme = context.theme;
    final canPop = context.canPop();

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('个人中心'),
        prefixes: canPop
            ? [FHeaderAction.back(onPress: () => context.pop())]
            : const [],
        suffixes: widget.isOwnProfile
            ? [
                FHeaderAction(
                  icon: const Icon(FLucideIcons.logOut),
                  semanticsLabel: '退出登录',
                  onPress: () =>
                      ref.read(authNotifierProvider.notifier).logout(),
                ),
              ]
            : const [],
      ),
      child: userAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(_userProfileProvider(widget.userId)),
        ),
        data: (user) {
          final isFollowing = _followOverride ?? user.isFollowing;
          final showFavoritesTab = widget.isOwnProfile || user.favoritesVisible;
          return NestedScrollView(
            floatHeaderSlivers: false,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CachedAvatar(
                            url: user.avatarUrl,
                            name: user.nickname.isNotEmpty
                                ? user.nickname
                                : user.username,
                            radius: 30,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.nickname.isNotEmpty
                                      ? user.nickname
                                      : user.username,
                                  style: theme.typography.display.md,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (user.bio.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    user.bio,
                                    style: theme.typography.body.sm.copyWith(
                                      color: theme.colors.mutedForeground,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _statColumn('帖子', user.postCount.toInt()),
                          _statColumn('粉丝', user.followerCount.toInt()),
                          _statColumn('关注', user.followingCount.toInt()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (widget.isOwnProfile) ...[
                        Row(
                          children: [
                            _shortcut(
                              FLucideIcons.userRoundPen,
                              '编辑资料',
                              '/profile/edit',
                            ),
                            const SizedBox(width: 8),
                            _shortcut(
                              FLucideIcons.notebook,
                              '记忆',
                              '/messages/assistant/memory',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const BusinessEntries(),
                        if (_personalizationEnabled != null) ...[
                          const SizedBox(height: 16),
                          FSwitch(
                            label: const Text('个性化推荐'),
                            value: _personalizationEnabled!,
                            enabled: !_personalizationBusy,
                            onChange: _setPersonalization,
                          ),
                        ],
                      ] else
                        FButton(
                          key: const Key('profile-follow-toggle'),
                          variant: isFollowing
                              ? FButtonVariant.secondary
                              : FButtonVariant.primary,
                          mainAxisSize: MainAxisSize.min,
                          onPress: _followBusy
                              ? null
                              : () => _toggleFollow(isFollowing),
                          child: Text(isFollowing ? '已关注' : '关注'),
                        ),
                    ],
                  ),
                ),
              ),
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: showFavoritesTab
                    ? PinnedHeaderSliver(
                        child: ColoredBox(
                          color: theme.colors.background,
                          child: FTabs(
                            control: FTabControl.lifted(
                              index: _tabIndex,
                              onChange: _selectTab,
                            ),
                            style: const FTabsStyleDelta.delta(spacing: 0),
                            children: [
                              FTabEntry(
                                label: Text(
                                  widget.isOwnProfile ? '我的帖子' : '帖子',
                                ),
                                child: const SizedBox.shrink(),
                              ),
                              FTabEntry(
                                label: Text(
                                  widget.isOwnProfile ? '我的收藏' : '收藏',
                                ),
                                child: const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      )
                    : const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
            body: showFavoritesTab
                ? PageView(
                    controller: _pageController,
                    onPageChanged: _handlePageChanged,
                    children: [
                      UserPostList(
                        userId: widget.userId,
                        type: UserPostsListType.posts,
                        active: _tabIndex == 0,
                      ),
                      UserPostList(
                        userId: widget.userId,
                        type: UserPostsListType.favorites,
                        active: _tabIndex == 1,
                      ),
                    ],
                  )
                : UserPostList(
                    userId: widget.userId,
                    type: UserPostsListType.posts,
                    active: true,
                  ),
          );
        },
      ),
    );
  }

  Widget _statColumn(String label, int count) {
    final theme = context.theme;
    return Column(
      children: [
        Text(
          '$count',
          style: theme.typography.display.lg.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          label,
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
      ],
    );
  }

  Widget _shortcut(IconData icon, String label, String route) => Expanded(
    child: FButton(
      variant: FButtonVariant.secondary,
      onPress: () => context.push(route),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

/// 「商业」分组：广告主控制台对已认证用户可见，审核工作台只对审核角色可见（FX-112）。
class BusinessEntries extends ConsumerWidget {
  const BusinessEntries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview = ref.watch(canReviewProvider);
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '商业',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FItemGroup(
          children: [
            FItem(
              key: const Key('profile-ads-console'),
              prefix: const Icon(FLucideIcons.megaphone),
              title: const Text('广告主控制台'),
              suffix: const Icon(FLucideIcons.chevronRight),
              onPress: () => context.push('/ads'),
            ),
            if (canReview)
              FItem(
                key: const Key('profile-review-workbench'),
                prefix: const Icon(FLucideIcons.clipboardCheck),
                title: const Text('审核工作台'),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: () => context.push('/review'),
              ),
          ],
        ),
      ],
    );
  }
}
