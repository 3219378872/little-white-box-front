import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../core/api/media_url.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../../behavior/application/behavior_tracker.dart';
import '../../../behavior/data/behavior_event.dart';
import '../../data/feed_models.dart';
import 'post_media_preview.dart';
import 'sponsored_ad_sheets.dart';
import 'sponsored_badge.dart';
import 'sponsored_exposure_timer.dart';

/// 打开外部落地页的注入点；测试替换它以避免真正拉起浏览器。
typedef ExternalUriOpener = Future<bool> Function(Uri uri);

/// 推荐流广告卡片（FX-100～FX-102、FX-104）。
///
/// 与帖子卡片同构，但头部固定显示广告主与「广告」标识，去掉互动统计，底部为落地页域名与
/// CTA。曝光沿用帖子卡片的 50% 可见、连续 1 秒判定，只上报曝光与点击，不上报停留。
class SponsoredAdCard extends ConsumerStatefulWidget {
  final SponsoredSlot slot;

  /// 所在列表是否可见；不可见时暂停曝光计时。
  final bool trackingActive;

  /// 隐藏广告；乐观移除与失败恢复由页面与 feed notifier 处理。
  final Future<void> Function() onHide;

  /// 以结构化原因代码举报广告。
  final Future<void> Function(String reason) onReport;

  /// 测试注入的外部打开器；为空时用系统浏览器在新窗口打开。
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

// 持有曝光计时器并监听前后台切换；隐藏、举报与落地页跳转都在这里发起。
class _SponsoredAdCardState extends ConsumerState<SponsoredAdCard>
    with WidgetsBindingObserver {
  final _exposure = SponsoredExposureTimer();

  SponsoredAd get ad => widget.slot.ad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant SponsoredAdCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 换了广告位允许重新曝光；追踪开关切换时暂停或恢复计时。
    if (oldWidget.slot.key != widget.slot.key) {
      _exposure.reset();
    }
    if (!widget.trackingActive) {
      _exposure.cancel();
    } else if (!oldWidget.trackingActive) {
      _scheduleExposure();
    }
  }

  // 切到后台时暂停曝光计时，回到前台再按最近一次可见比例恢复。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleExposure();
    } else {
      _exposure.cancel();
    }
  }

  @override
  void dispose() {
    _exposure.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 可见比例达到阈值时尝试开始曝光计时，低于阈值时计时器自行取消。
  void _onVisibilityChanged(VisibilityInfo info) {
    if (_exposure.updateVisibility(info.visibleFraction)) {
      _scheduleExposure();
    }
  }

  // 计时开始时锁定当前广告位；到点时广告位已变或追踪关闭则不上报。
  void _scheduleExposure() {
    if (!mounted || !widget.trackingActive) return;
    final slot = widget.slot;
    _exposure.schedule(
      stillValid: () =>
          mounted && widget.trackingActive && widget.slot.key == slot.key,
      onExposed: () => _trackSafely(
        () => ref
            .read(behaviorTrackerProvider)
            .trackExposure(
              slot.ad.adId,
              slot.context,
              targetType: behaviorTargetAd,
            ),
      ),
    );
  }

  // 行为上报异步执行且吞掉异常，不打断用户操作。
  void _trackSafely(Future<void> Function() track) {
    unawaited(() async {
      try {
        await track();
      } catch (_) {
        // Analytics failures must not interrupt the user action.
      }
    }());
  }

  // 点击卡片或 CTA：先记点击，再尝试外部打开落地页，失败时提示域名。
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

  // 隐藏/举报前停止曝光计时，避免被移除的广告仍补报曝光。
  void _hide() {
    _exposure.cancel();
    unawaited(widget.onHide());
  }

  // 举报：先在底部面板选择原因，取消选择则不提交；提交前同样停止曝光计时。
  Future<void> _report() async {
    final reason = await showFSheet<String>(
      context: context,
      side: FLayout.btt,
      builder: (context) => SponsoredReportSheet(ad: ad),
    );
    if (reason == null || !mounted) return;
    _exposure.cancel();
    await widget.onReport(reason);
  }

  // 展示「为什么看到这条广告」面板。
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
                // 头部：广告主名、「广告」标识与更多菜单。
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
                      // 广告配图复用帖子卡片的预览布局，相对路径先解析为完整地址。
                      if (ad.images.isNotEmpty) ...[
                        const SizedBox(height: AppTheme.space3),
                        PostMediaPreview(
                          images: ad.images.map(resolveImageUrl).toList(),
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

  // 底部行：落地页域名与 CTA 按钮（无文案时显示「了解更多」）。
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

  // 更多菜单：为什么看到、隐藏、举报；选择后先收起菜单再执行。
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
}
