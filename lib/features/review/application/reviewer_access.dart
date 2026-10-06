import 'package:flutter/widgets.dart';
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

  static const none = ReviewerAccess();

  bool get canReview => active && roles.any(reviewWorkbenchRoles.contains);
}

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

/// 应用回到前台时刷新审核授权，使角色变更无需重新登录即可生效。
class ReviewerAccessRefreshBinding extends ConsumerStatefulWidget {
  const ReviewerAccessRefreshBinding({super.key});

  @override
  ConsumerState<ReviewerAccessRefreshBinding> createState() =>
      _ReviewerAccessRefreshBindingState();
}

class _ReviewerAccessRefreshBindingState
    extends ConsumerState<ReviewerAccessRefreshBinding> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        if (ref.read(authenticatedSessionIdentityProvider) == null) return;
        ref.invalidate(reviewerAccessProvider);
      },
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
