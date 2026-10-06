import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_notifier.dart';
import 'review_dependencies.dart';

/// 可处理审核任务的角色；`policy_admin` 只管理政策，不进入工作台。
const reviewWorkbenchRoles = {'reviewer', 'qa', 'qualification_reviewer'};

/// 当前用户的审核授权，仅用于决定入口显示（FX-112）；服务端仍是唯一权限依据。
class ReviewerAccess {
  final bool active;
  final List<String> roles;
  final List<String> markets;
  final List<String> languages;

  const ReviewerAccess({
    this.active = false,
    this.roles = const [],
    this.markets = const [],
    this.languages = const [],
  });

  /// 未登录时的空授权。
  static const none = ReviewerAccess();

  /// 档案已启用且至少拥有一个工作台角色。
  bool get canReview => active && roles.any(reviewWorkbenchRoles.contains);
}

/// 当前登录身份的审核授权；未登录时为 [ReviewerAccess.none]，身份变化时重新读取。
final reviewerAccessProvider = FutureProvider<ReviewerAccess>((ref) async {
  final identity = ref.watch(authenticatedSessionIdentityProvider);
  if (identity == null) return ReviewerAccess.none;
  final profile = await ref.read(reviewRepositoryProvider).getProfile();
  return ReviewerAccess(
    active: profile.active,
    roles: List.unmodifiable(profile.roles),
    markets: List.unmodifiable(profile.markets),
    languages: List.unmodifiable(profile.languages),
  );
});

/// 入口可见性：请求失败或未加载完成时按无权限处理。
final canReviewProvider = Provider<bool>((ref) {
  return ref.watch(reviewerAccessProvider).value?.canReview ?? false;
});
