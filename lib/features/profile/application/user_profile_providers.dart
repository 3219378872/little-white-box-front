import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import 'profile_dependencies.dart';

/// 个人页展示的用户资料；随会话身份重建，换号后不复用上一账号的关注态。
final userProfileProvider = FutureProvider.autoDispose
    .family<GetUserResp, String>((ref, userId) {
      ref.watch(authSessionIdentityProvider);
      return ref.read(userRepositoryProvider).getUserProfile(userId);
    });

/// 当前登录用户是否关注 [userId]；帖子详情的作者行复用资料接口读取。
final userFollowingProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  userId,
) async {
  ref.watch(authSessionIdentityProvider);
  final user = await ref.read(userRepositoryProvider).getUserProfile(userId);
  return user.isFollowing;
});
