import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../core/widgets/app_badge.dart';
import '../data/ad_labels.dart';

/// 审核状态标签：文字表达状态，颜色只作辅助（FQ-010）。
class ReviewStatusBadge extends StatelessWidget {
  final String status;

  const ReviewStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      variant: switch (status) {
        'rejected' => FBadgeVariant.destructive,
        'approved' => FBadgeVariant.primary,
        _ => FBadgeVariant.secondary,
      },
      child: Text('审核：${adReviewStatusLabel(status)}'),
    );
  }
}

class ServingStatusBadge extends StatelessWidget {
  final String status;

  const ServingStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      variant: status == 'serving'
          ? FBadgeVariant.primary
          : FBadgeVariant.outline,
      child: Text('投放：${adServingStatusLabel(status)}'),
    );
  }
}
