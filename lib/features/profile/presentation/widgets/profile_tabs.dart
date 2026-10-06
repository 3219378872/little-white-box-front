import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../application/user_posts_notifier.dart';
import 'user_post_list.dart';

/// 个人主页的「帖子/收藏」标签栏，吸顶时用页面背景色遮住下方内容。
///
/// 选中态由页面持有，并与 [ProfileTabPages] 的翻页保持同步。
class ProfileTabBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChange;

  /// 本人主页的标签文案带「我的」前缀。
  final bool isOwnProfile;

  const ProfileTabBar({
    super.key,
    required this.index,
    required this.onChange,
    required this.isOwnProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.theme.colors.background,
      child: FTabs(
        control: FTabControl.lifted(index: index, onChange: onChange),
        style: const FTabsStyleDelta.delta(spacing: 0),
        children: [
          FTabEntry(
            label: Text(isOwnProfile ? '我的帖子' : '帖子'),
            child: const SizedBox.shrink(),
          ),
          FTabEntry(
            label: Text(isOwnProfile ? '我的收藏' : '收藏'),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// 个人主页的标签内容：可滑动切换的帖子列表与收藏列表。
///
/// 只有当前标签的列表处于 active：切到该标签或从子页返回时才刷新，后台标签不刷新。
class ProfileTabPages extends StatelessWidget {
  final String userId;
  final int index;
  final PageController controller;
  final ValueChanged<int> onPageChanged;

  const ProfileTabPages({
    super.key,
    required this.userId,
    required this.index,
    required this.controller,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: controller,
      onPageChanged: onPageChanged,
      children: [
        UserPostList(
          userId: userId,
          type: UserPostsListType.posts,
          active: index == 0,
        ),
        UserPostList(
          userId: userId,
          type: UserPostsListType.favorites,
          active: index == 1,
        ),
      ],
    );
  }
}
