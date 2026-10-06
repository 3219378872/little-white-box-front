import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/widgets/cached_avatar.dart';
import '../../../../sdk/data/gateway.dart';

/// 个人主页头部：头像、昵称（未设置时回落到用户名）与简介。
class ProfileHeader extends StatelessWidget {
  final GetUserResp user;

  const ProfileHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final displayName = user.nickname.isNotEmpty
        ? user.nickname
        : user.username;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CachedAvatar(url: user.avatarUrl, name: displayName, radius: 30),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
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
    );
  }
}
