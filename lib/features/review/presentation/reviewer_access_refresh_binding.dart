import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_notifier.dart';
import '../application/reviewer_access.dart';

/// 应用回到前台时刷新审核授权，使角色变更无需重新登录即可生效。
class ReviewerAccessRefreshBinding extends ConsumerStatefulWidget {
  const ReviewerAccessRefreshBinding({super.key});

  @override
  ConsumerState<ReviewerAccessRefreshBinding> createState() =>
      _ReviewerAccessRefreshBindingState();
}

// 持有生命周期监听，随壳层释放。
class _ReviewerAccessRefreshBindingState
    extends ConsumerState<ReviewerAccessRefreshBinding> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onResume: () {
        if (!mounted) return;
        // 未登录时没有授权可刷新。
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
