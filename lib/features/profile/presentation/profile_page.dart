import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../auth/application/auth_notifier.dart';
import '../application/follow_controller.dart';
import '../application/personalization_controller.dart';
import '../application/user_posts_notifier.dart';
import '../application/user_profile_providers.dart';
import 'widgets/business_entries.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_shortcuts.dart';
import 'widgets/profile_stats.dart';
import 'widgets/profile_tabs.dart';
import 'widgets/user_post_list.dart';

/// 个人主页：不带 [userId] 时展示当前登录用户，匿名时引导登录。
///
/// 以会话版本和目标用户作为内容 key，切换账号或用户时整体重建，避免沿用旧用户的状态。
class ProfilePage extends ConsumerWidget {
  final Object? userId;
  const ProfilePage({super.key, this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final targetUserId = userId ?? auth.userId;

    // 目标用户无效（通常是未登录时打开本人主页）：给登录引导。
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
                onPress: () => context.push(AppRoutes.login),
                child: const Text('去登录'),
              ),
            ],
          ),
        ),
      );
    }

    // 不带 userId，或带的正是自己的 ID，都按本人主页处理。
    final isOwnProfile =
        userId == null || jsonInt64Id(userId) == jsonInt64Id(auth.userId);

    return _ProfileContent(
      key: ValueKey('${auth.sessionRevision}:${jsonInt64Id(targetUserId)}'),
      userId: jsonInt64Id(targetUserId),
      isOwnProfile: isOwnProfile,
    );
  }
}

// 已确定目标用户后的主页内容：头部资料区、吸顶标签栏与帖子/收藏列表。
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

// 持有当前标签下标与翻页控制器，并处理关注、个性化开关的写操作。
class _ProfileContentState extends ConsumerState<_ProfileContent> {
  int _tabIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 点标签与左右滑动双向同步：点标签时动画翻页，翻页回调再回写选中态。
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

  // 左右滑动翻页后回写选中标签。
  void _handlePageChanged(int index) {
    if (index != _tabIndex) {
      setState(() => _tabIndex = index);
    }
  }

  // 个性化开关的写入与回滚由 controller 负责，页面只负责失败提示。
  Future<void> _setPersonalization(bool enabled) async {
    try {
      await ref
          .read(personalizationControllerProvider.notifier)
          .setEnabled(enabled);
    } catch (e) {
      if (!mounted) return;
      showAppError(context, '个性化设置失败: ${friendlyErrorMessage(e)}');
    }
  }

  // 匿名用户先去登录；关注的乐观更新与回滚由共享的 follow controller 负责。
  Future<void> _toggleFollow(bool isFollowing) async {
    final follow = followControllerProvider(widget.userId);
    if (ref.read(follow).isBusy) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) {
      context.push(AppRoutes.login);
      return;
    }
    try {
      await ref.read(follow.notifier).toggle(isFollowing);
    } catch (e) {
      if (!mounted) return;
      showAppError(context, '操作失败: ${friendlyErrorMessage(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider(widget.userId));
    final follow = ref.watch(followControllerProvider(widget.userId));
    // 只有本人主页展示个性化开关，也只在此时读取偏好。
    final personalization = widget.isOwnProfile
        ? ref.watch(personalizationControllerProvider)
        : null;
    // 没有可返回的页面（如作为底部导航根页）时不显示返回按钮。
    final canPop = context.canPop();

    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: const Text('个人中心'),
        prefixes: canPop
            ? [FHeaderAction.back(onPress: () => context.pop())]
            : const [],
        // 本人主页顶栏提供退出登录。
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
        // 资料加载中与加载失败（可重试）。
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: friendlyErrorMessage(e),
          onRetry: () => ref.invalidate(userProfileProvider(widget.userId)),
        ),
        data: (user) {
          // 本地关注操作结果优先于资料接口返回的关注态。
          final isFollowing = follow.resolve(user.isFollowing);
          final showFavoritesTab = widget.isOwnProfile || user.favoritesVisible;
          // 收藏不公开的他人主页只有帖子列表，不显示标签栏。
          return NestedScrollView(
            floatHeaderSlivers: false,
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              // 头部：资料、计数与按身份区分的操作区。
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      ProfileHeader(user: user),
                      const SizedBox(height: 24),
                      ProfileStats(user: user),
                      const SizedBox(height: 16),
                      // 本人：快捷入口、商业入口与个性化开关；他人：关注按钮
                      if (widget.isOwnProfile) ...[
                        const ProfileShortcuts(),
                        const SizedBox(height: 16),
                        const BusinessEntries(),
                        // 偏好读取成功后才显示个性化开关。
                        if (personalization?.enabled case final enabled?) ...[
                          const SizedBox(height: 16),
                          FSwitch(
                            label: const Text('个性化推荐'),
                            value: enabled,
                            enabled: !personalization!.isBusy,
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
                          onPress: follow.isBusy
                              ? null
                              : () => _toggleFollow(isFollowing),
                          child: Text(isFollowing ? '已关注' : '关注'),
                        ),
                    ],
                  ),
                ),
              ),
              // 吸顶标签栏；收藏不可见时放空 sliver，吸收器始终存在以与列表里的 SliverOverlapInjector 配对。
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(
                  context,
                ),
                sliver: showFavoritesTab
                    ? PinnedHeaderSliver(
                        child: ProfileTabBar(
                          index: _tabIndex,
                          onChange: _selectTab,
                          isOwnProfile: widget.isOwnProfile,
                        ),
                      )
                    : const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
            // 可切换的帖子/收藏页，或只有帖子列表。
            body: showFavoritesTab
                ? ProfileTabPages(
                    userId: widget.userId,
                    index: _tabIndex,
                    controller: _pageController,
                    onPageChanged: _handlePageChanged,
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
}
