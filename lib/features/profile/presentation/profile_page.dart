import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/widgets/cached_avatar.dart';
import '../../../core/widgets/error_view.dart';
import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/user_posts_notifier.dart';
import '../data/user_repository.dart';
import 'widgets/user_post_list.dart';

final _userRepoProvider = Provider((ref) => UserRepository());

final _userProfileProvider =
    FutureProvider.family<GetUserResp, int>((ref, userId) {
  return ref.read(_userRepoProvider).getUserProfile(userId);
});

class ProfilePage extends ConsumerWidget {
  final int? userId;
  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final targetUserId = userId ?? auth.userId?.toInt();

    if (targetUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('个人中心')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('请先登录'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.push('/auth/login'),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    final isOwnProfile = userId == null || userId == auth.userId?.toInt();

    return _ProfileContent(
      userId: targetUserId,
      isOwnProfile: isOwnProfile,
    );
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final int userId;
  final bool isOwnProfile;

  const _ProfileContent({
    required this.userId,
    required this.isOwnProfile,
  });

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    // tabController created lazily in build via _ensureTabController
  }

  TabController? _ensureTabController(bool showFavoritesTab) {
    if (!showFavoritesTab) {
      _tabController?.dispose();
      return _tabController = null;
    }
    if (_tabController == null || _tabController!.length != 2) {
      _tabController?.dispose();
      _tabController = TabController(length: 2, vsync: this);
    }
    return _tabController;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(_userProfileProvider(widget.userId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('个人中心'),
        actions: widget.isOwnProfile
            ? [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () =>
                      ref.read(authNotifierProvider.notifier).logout(),
                ),
              ]
            : null,
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(_userProfileProvider(widget.userId)),
        ),
        data: (user) {
          final showFavoritesTab = widget.isOwnProfile || user.favoritesVisible;
          _ensureTabController(showFavoritesTab);
          return NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    CachedAvatar(url: user.avatarUrl, radius: 28),
                    const SizedBox(height: 12),
                    Text(
                      user.nickname.isNotEmpty ? user.nickname : user.username,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(user.bio,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                    const SizedBox(height: 16),
                    // 统计
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _statColumn('帖子', user.postCount.toInt()),
                        _statColumn('粉丝', user.followerCount.toInt()),
                        _statColumn('关注', user.followingCount.toInt()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 操作按钮
                    if (widget.isOwnProfile)
                      OutlinedButton(
                        onPressed: () => context.push('/profile/edit'),
                        child: const Text('编辑资料'),
                      )
                    else
                      FilledButton(
                        onPressed: _toggleFollow,
                        style: _isFollowing
                            ? FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                foregroundColor: theme.colorScheme.onSurface,
                              )
                            : null,
                        child: Text(_isFollowing ? '已关注' : '关注'),
                      ),
                  ],
                ),
              ),
            ),
            if ((widget.isOwnProfile || user.favoritesVisible) && _tabController != null)
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: widget.isOwnProfile ? '我的帖子' : '帖子'),
                      Tab(text: widget.isOwnProfile ? '我的收藏' : '收藏'),
                    ],
                  ),
                  theme.colorScheme.surface,
                ),
              ),
          ],
          body: (showFavoritesTab && _tabController != null)
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    UserPostList(
                      userId: widget.userId,
                      type: UserPostsListType.posts,
                    ),
                    UserPostList(
                      userId: widget.userId,
                      type: UserPostsListType.favorites,
                    ),
                  ],
                )
              : UserPostList(
                  userId: widget.userId,
                  type: UserPostsListType.posts,
                ),
        );
        },
      ),
    );
  }

  Widget _statColumn(String label, int count) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;
  _TabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
