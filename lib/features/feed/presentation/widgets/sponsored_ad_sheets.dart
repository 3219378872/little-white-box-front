import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../ads/presentation/ad_labels.dart';
import '../../data/feed_models.dart';

/// 「为什么看到这条广告」：展示服务端返回的市场、场景与是否个性化（FX-101）。
class SponsoredWhySheet extends StatelessWidget {
  final SponsoredAd ad;

  const SponsoredWhySheet({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final why = ad.why;
    // 一行「标签：值」，标签列定宽对齐。
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.space1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.typography.body.sm.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.typography.body.sm)),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text('为什么看到这条广告', style: theme.typography.display.sm),
              ),
              const SizedBox(height: AppTheme.space3),
              // 逐项列出投放依据；首页场景显示为中文名，其余原样展示。
              row('广告主', ad.advertiserName),
              row('投放市场', why.market.isEmpty ? '未提供' : why.market),
              row('展示场景', why.scene == 'home' ? '首页推荐' : why.scene),
              row('个性化', why.personalized ? '是' : '否'),
              const SizedBox(height: AppTheme.space2),
              // 按是否个性化给出一句说明。
              Text(
                why.personalized
                    ? '这条广告参考了你的个性化信息。'
                    : '这条广告按投放市场与场景展示，没有根据你的个人兴趣定向。',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 举报原因选择（FX-101）：选择即提交，关闭面板不提交。原因只取结构化选项，不收集自由文本。
class SponsoredReportSheet extends StatelessWidget {
  final SponsoredAd ad;

  const SponsoredReportSheet({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colors.background,
        border: Border(top: BorderSide(color: theme.colors.border)),
      ),
      child: SafeArea(
        top: false,
        // 面板高度受限（矮屏或横屏），选项过多时滚动而不是溢出。
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text('举报这条广告', style: theme.typography.display.sm),
              ),
              const SizedBox(height: AppTheme.space1),
              Text(
                '举报后这条广告将不再向你展示，并由审核员复核。',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: AppTheme.space3),
              // 原因选项：点选即以原因代码关闭面板。
              FItemGroup(
                children: [
                  for (final (code, label) in adReportReasons)
                    FItem(
                      key: Key('ad-report-reason-$code'),
                      title: Text(label),
                      suffix: const Icon(FLucideIcons.chevronRight),
                      onPress: () => Navigator.of(context).pop(code),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
