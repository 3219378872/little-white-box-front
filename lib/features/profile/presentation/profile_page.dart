import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/user_posts_notifier.dart';
import '../data/personalization_repository.dart';
import '../data/user_repository.dart';
import 'widgets/user_post_list.dart';

final _userRepoProvider = Provider((ref) => UserRepository());
final _personalizationRepoProvider = Provider(
  (ref) => PersonalizationRepository(),
);

final _userProfileProvider = FutureProvider.family<GetUserResp, String>((
  ref,
  userId,
) {
  return ref.read(_userRepoProvider).getUserProfile(userId);
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
        userId == null ||
        jsonInt64Id(userId) == jsonInt64Id(auth.userId);

    return _ProfileContent(
      userId: jsonInt64Id(targetUserId),
      isOwnProfile: isOwnProfile,
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const _ProfileContent({required this.userId, required this.isOwnProfile});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  bool _isFollowing = false;
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
          .read(_personalizationRepoProvider)
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
          .read(_personalizationRepoProvider)
          .setPreference(enabled: enabled);
    } catch (e) {
      if (!mounted) return;
      setState(() => _personalizationEnabled = previous);
      showAppError(context, '个性化设置失败: $e');
    } finally {
      if (mounted) setState(() => _personalizationBusy = false);
    }
  }

  Future<void> _toggleFollow() async {
    final repo = ref.read(_userRepoProvider);
    final wasFollowing = _isFollowing;
    setState(() => _isFollowing = !_isFollowing);
    try {
      if (wasFollowing) {
        await repo.unfollowUser(widget.userId);
      } else {
        await repo.followUser(widget.userId);
      }
    } catch (e) {
      setState(() => _isFollowing = wasFollowing);
      if (mounted) {
        showAppError(context, '操作失败: $e');
      }
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
        loading: () => const Center(child: FCircularProgress()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_userProfileProvider(widget.userId)),
        ),
        data: (user) {
          final showFavoritesTab = widget.isOwnProfile || user.favoritesVisible;
          return NestedScrollView(
            floatHeaderSlivers: false,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CachedAvatar(
                        url: user.avatarUrl,
                        name: user.nickname.isNotEmpty
                            ? user.nickname
                            : user.username,
                        radius: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user.nickname.isNotEmpty
                            ? user.nickname
                            : user.username,
                        style: theme.typography.display.sm.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (user.bio.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          user.bio,
                          style: theme.typography.body.sm.copyWith(
                            color: theme.colors.mutedForeground,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
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
                        FButton(
                          variant: .outline,
                          mainAxisSize: MainAxisSize.min,
                          onPress: () => context.push('/profile/edit'),
                          child: const Text('编辑资料'),
                        ),
                        const SizedBox(height: 12),
                        FButton(
                          variant: .ghost,
                          mainAxisSize: MainAxisSize.min,
                          prefix: const Icon(FLucideIcons.sparkles),
                          onPress: () => context.go('/assistant'),
                          child: const Text('Assistant'),
                        ),
                        if (_personalizationEnabled != null) ...[
                          const SizedBox(height: 16),
                          FSwitch(
                            label: const Text('个性化推荐'),
                            description: const Text('关闭后不再用你的行为做个性化'),
                            value: _personalizationEnabled!,
                            enabled: !_personalizationBusy,
                            onChange: _setPersonalization,
                          ),
                        ],
                      ] else
                        FButton(
                          variant: _isFollowing
                              ? FButtonVariant.secondary
                              : FButtonVariant.primary,
                          mainAxisSize: MainAxisSize.min,
                          onPress: _toggleFollow,
                          child: Text(_isFollowing ? '已关注' : '关注'),
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
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.bold),
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
}
