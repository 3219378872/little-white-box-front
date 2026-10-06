import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../sdk/data/gateway.dart';

/// 个人主页计数行：帖子、粉丝、关注三项等分排列。
class ProfileStats extends StatelessWidget {
  final GetUserResp user;

  const ProfileStats({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatColumn(label: '帖子', count: user.postCount.toInt()),
        _StatColumn(label: '粉丝', count: user.followerCount.toInt()),
        _StatColumn(label: '关注', count: user.followingCount.toInt()),
      ],
    );
  }
}

// 单项计数：大号数字在上，说明文字在下。
class _StatColumn extends StatelessWidget {
  final String label;
  final int count;

  const _StatColumn({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
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
}
