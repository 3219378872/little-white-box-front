import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../review/application/reviewer_access.dart';

/// 「商业」分组：广告主控制台对已认证用户可见，审核工作台只对审核角色可见（FX-112）。
class BusinessEntries extends ConsumerWidget {
  const BusinessEntries({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReview = ref.watch(canReviewProvider);
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            '商业',
            style: theme.typography.body.sm.copyWith(
              color: theme.colors.mutedForeground,
            ),
          ),
        ),
        const SizedBox(height: 8),
        FItemGroup(
          children: [
            FItem(
              key: const Key('profile-ads-console'),
              prefix: const Icon(FLucideIcons.megaphone),
              title: const Text('广告主控制台'),
              suffix: const Icon(FLucideIcons.chevronRight),
              onPress: () => context.push(AppRoutes.ads),
            ),
            if (canReview)
              FItem(
                key: const Key('profile-review-workbench'),
                prefix: const Icon(FLucideIcons.clipboardCheck),
                title: const Text('审核工作台'),
                suffix: const Icon(FLucideIcons.chevronRight),
                onPress: () => context.push(AppRoutes.review),
              ),
          ],
        ),
      ],
    );
  }
}
