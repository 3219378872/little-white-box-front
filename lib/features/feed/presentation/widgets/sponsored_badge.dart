import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_badge.dart';

/// 文本「广告」与图标并列的标识，辅助技术读作「广告」（FX-100、FQ-010）。
class SponsoredBadge extends StatelessWidget {
  const SponsoredBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      variant: AppTheme.sponsoredBadgeVariant,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ExcludeSemantics(
            child: Icon(
              FLucideIcons.megaphone,
              size: AppTheme.sponsoredBadgeIconSize,
            ),
          ),
          const SizedBox(width: 3),
          const Text('广告'),
        ],
      ),
    );
  }
}
