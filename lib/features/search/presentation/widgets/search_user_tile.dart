import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/widgets/cached_avatar.dart';
import '../../data/search_models.dart';

/// 搜索结果中的用户条目：头像、昵称、简介（无简介时显示用户名）与关注者数。
class SearchUserTile extends StatelessWidget {
  final SearchUserResult user;
  final ValueChanged<Object> onOpenUser;

  const SearchUserTile({
    super.key,
    required this.user,
    required this.onOpenUser,
  });

  @override
  Widget build(BuildContext context) {
    return FItem(
      prefix: CachedAvatar(
        url: user.avatarUrl,
        name: user.displayName,
        radius: 20,
      ),
      title: Text(
        user.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        user.bio.isEmpty ? '@${user.username}' : user.bio,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      details: Text('${user.followerCount} 关注者'),
      suffix: const Icon(FLucideIcons.chevronRight),
      onPress: () => onOpenUser(user.id),
    );
  }
}
