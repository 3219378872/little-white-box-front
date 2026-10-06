import 'dart:async';

/// 广告卡片的曝光判定（FX-100～FX-102）：可见比例达到 50% 且连续 1 秒才算一次曝光。
///
/// 只负责可见比例、计时与「同一广告位只判定一次」的去重；计时能否开始、到点时是否仍有效
/// 以及如何上报，由持有它的卡片在调用时注入，卡片同时负责在销毁时调用 [cancel]。
class SponsoredExposureTimer {
  /// 视为可见的最小可见比例。
  static const visibilityThreshold = 0.5;

  /// 达到可见比例后需要持续的时间。
  static const exposureThreshold = Duration(seconds: 1);

  Timer? _timer;
  bool _reported = false;
  double _lastVisibleFraction = 0;

  /// 记录最新可见比例；低于阈值时取消进行中的计时，返回当前是否达到阈值。
  bool updateVisibility(double visibleFraction) {
    _lastVisibleFraction = visibleFraction;
    if (visibleFraction < visibilityThreshold) {
      cancel();
      return false;
    }
    return true;
  }

  /// 在足够可见、尚未曝光且没有进行中计时时开始计时。
  ///
  /// 到点后先用 [stillValid] 复核（卡片仍挂载、追踪仍开启、广告位未变），通过才标记已曝光
  /// 并调用 [onExposed]；复核失败不计入，后续可见性变化可重新计时。
  void schedule({
    required bool Function() stillValid,
    required void Function() onExposed,
  }) {
    if (_reported ||
        _timer != null ||
        _lastVisibleFraction < visibilityThreshold) {
      return;
    }
    _timer = Timer(exposureThreshold, () {
      _timer = null;
      if (!stillValid()) return;
      _reported = true;
      onExposed();
    });
  }

  /// 取消尚未到点的计时（离屏、切后台、隐藏或举报时），不影响已曝光标记。
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// 卡片换成另一个广告位时调用：取消计时并允许新广告位重新曝光。
  void reset() {
    cancel();
    _reported = false;
  }
}
