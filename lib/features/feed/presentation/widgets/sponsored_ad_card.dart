import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../../sdk/vars/vars.dart';
import '../../../behavior/application/behavior_tracker.dart';
import '../../../ads/data/ad_labels.dart';
import '../../../behavior/data/behavior_event.dart';
import '../../data/feed_models.dart';
import 'post_media_preview.dart';

typedef ExternalUriOpener = Future<bool> Function(Uri uri);

/// 推荐流广告卡片（FX-100～FX-102、FX-104）。
///
/// 与帖子卡片同构，但头部固定显示广告主与「广告」标识，去掉互动统计，底部为落地页域名与
/// CTA。曝光沿用帖子卡片的 50% 可见、连续 1 秒判定，只上报曝光与点击，不上报停留。
class SponsoredAdCard extends ConsumerStatefulWidget {
  final SponsoredSlot slot;
  final bool trackingActive;
  final Future<void> Function() onHide;
  final Future<void> Function(String reason) onReport;
  final ExternalUriOpener? openExternal;

  const SponsoredAdCard({
    super.key,
    required this.slot,
    required this.onHide,
    required this.onReport,
    this.trackingActive = true,
    this.openExternal,
  });

  @override
  ConsumerState<SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _SponsoredAdCardState extends ConsumerState<SponsoredAdCard>
    with WidgetsBindingObserver {
  static const _visibilityThreshold = 0.5;
  static const _exposureThreshold = Duration(seconds: 1);

  Timer? _exposureTimer;
  bool _exposureReported = false;
  double _lastVisibleFraction = 0;

  SponsoredAd get ad => widget.slot.ad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant SponsoredAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slot.key != widget.slot.key) {
      _cancelExposure();
      _exposureReported = false;
    }
    if (!widget.trackingActive) {
      _cancelExposure();
    } else if (!oldWidget.trackingActive) {
      _scheduleExposure();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleExposure();
    } else {
      _cancelExposure();
    }
  }

  @override
  void dispose() {
    _cancelExposure();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    _lastVisibleFraction = info.visibleFraction;
    if (info.visibleFraction < _visibilityThreshold) {
      _cancelExposure();
      return;
    }
    _scheduleExposure();
  }

  void _scheduleExposure() {
    if (!mounted ||
        !widget.trackingActive ||
        _exposureReported ||
        _exposureTimer != null ||
        _lastVisibleFraction < _visibilityThreshold) {
      return;
    }
    final slot = widget.slot;
    _exposureTimer = Timer(_exposureThreshold, () {
      _exposureTimer = null;
      if (!mounted || !widget.trackingActive || widget.slot.key != slot.key) {
        return;
      }
      _exposureReported = true;
      _trackSafely(
        () => ref
            .read(behaviorTrackerProvider)
            .trackExposure(
              slot.ad.adId,
              slot.context,
              targetType: behaviorTargetAd,
            ),
      );
    });
  }

  void _cancelExposure() {
    _exposureTimer?.cancel();
    _exposureTimer = null;
  }

  void _trackSafely(Future<void> Function() track) {
    unawaited(() async {
      try {
        await track();
      } catch (_) {
        // Analytics failures must not interrupt the user action.
      }
    }());
  }

  Future<void> _openLanding() async {
    _trackSafely(
      () => ref
          .read(behaviorTrackerProvider)
          .trackClick(
            ad.adId,
            widget.slot.context,
            targetType: behaviorTargetAd,
          ),
    );
    try {
      final opened =
          await (widget.openExternal?.call(ad.landingUri) ??
              launchUrl(
                ad.landingUri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (!opened && mounted) showAppError(context, '无法打开 ${ad.landingDomain}');
    } catch (_) {
      if (mounted) showAppError(context, '无法打开 ${ad.landingDomain}');
    }
  }

  void _hide() {
    _cancelExposure();
    unawaited(widget.onHide());
  }

  Future<void> _report() async {
    final reason = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SponsoredReportSheet(ad: ad),
    );
    if (reason == null || !mounted) return;
    _cancelExposure();
    await widget.onReport(reason);
  }

  Future<void> _showWhy() {
    return showFSheet<void>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SponsoredWhySheet(ad: ad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final typography = theme.typography;
    return VisibilityDetector(
      key: Key('ad-exposure-${widget.slot.key}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Semantics(
        container: true,
        label: '广告，由 ${ad.advertiserName} 推广',
        child: FTappable(
          onPress: _openLanding,
          semanticsLabel: '打开 ${ad.landingDomain}：${ad.title}',
          builder: (context, variants, child) => DecoratedBox(
            decoration: BoxDecoration(
              color:
                  variants.contains(FTappableVariant.hovered) ||
                      variants.contains(FTappableVariant.pressed)
                  ? colors.muted
                  : colors.background,
              border: Border(bottom: BorderSide(color: colors.border)),
            ),
            child: child,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.pageInset,
              AppTheme.space2,
              AppTheme.space2,
              AppTheme.space3,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Name takes all free width so only long names truncate.
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              ad.advertiserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: typography.body.sm.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.space2),
                          const SponsoredBadge(),
                        ],
                      ),
                    ),
                    _menu(),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.space2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ad.title,
                        style: typography.body.lg.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (ad.body.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTheme.space1),
                          child: Text(
                            ad.body,
                            style: typography.body.sm.copyWith(
                              color: colors.secondaryForeground,
                              height: 1.6,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (ad.images.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space3),
                        PostMediaPreview(
                          images: ad.images.map(_resolveImage).toList(),
                        ),
                      ],
                      const SizedBox(height: AppTheme.space3),
                      _ctaRow(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ctaRow(BuildContext context) {
    final theme = context.theme;
    final domainColor = AppTheme.sponsoredDomain(theme.colors);
    return Row(
      children: [
        Icon(FLucideIcons.globe, size: 14, color: domainColor),
        const SizedBox(width: AppTheme.space1),
        Expanded(
          child: Text(
            ad.landingDomain,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.typography.body.xs.copyWith(color: domainColor),
          ),
        ),
        const SizedBox(width: AppTheme.space2),
        FButton(
          key: Key('ad-cta-${widget.slot.key}'),
          size: AppTheme.sponsoredCtaSize,
          mainAxisSize: MainAxisSize.min,
          suffix: const Icon(FLucideIcons.externalLink),
          onPress: _openLanding,
          child: Text(ad.cta.isEmpty ? '了解更多' : ad.cta),
        ),
      ],
    );
  }

  Widget _menu() {
    return FPopoverMenu(
      menuAnchor: Alignment.topRight,
      childAnchor: Alignment.bottomRight,
      menuBuilder: (context, controller, _) => [
        FItemGroup(
          children: [
            FItem(
              key: const Key('ad-why'),
              prefix: const Icon(FLucideIcons.info),
              title: const Text('为什么看到这条广告'),
              onPress: () {
                controller.hide();
                unawaited(_showWhy());
              },
            ),
            FItem(
              key: const Key('ad-hide'),
              prefix: const Icon(FLucideIcons.eyeOff),
              title: const Text('隐藏这条广告'),
              onPress: () {
                controller.hide();
                _hide();
              },
            ),
            FItem(
              key: const Key('ad-report'),
              prefix: const Icon(FLucideIcons.flag),
              title: const Text('举报这条广告'),
              onPress: () {
                controller.hide();
                unawaited(_report());
              },
            ),
          ],
        ),
      ],
      builder: (context, controller, _) => AppIconButton(
        key: Key('ad-menu-${widget.slot.key}'),
        icon: FLucideIcons.ellipsis,
        label: '广告选项',
        onPress: controller.toggle,
      ),
    );
  }

  static String _resolveImage(String raw) {
    final uri = Uri.parse(raw);
    return uri.hasScheme ? raw : apiUri(raw).toString();
  }
}

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

/// 「为什么看到这条广告」：展示服务端返回的市场、场景与是否个性化（FX-101）。
class SponsoredWhySheet extends StatelessWidget {
  final SponsoredAd ad;

  const SponsoredWhySheet({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final why = ad.why;
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
              row('广告主', ad.advertiserName),
              row('投放市场', why.market.isEmpty ? '未提供' : why.market),
              row('展示场景', why.scene == 'home' ? '首页推荐' : why.scene),
              row('个性化', why.personalized ? '是' : '否'),
              const SizedBox(height: AppTheme.space2),
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
