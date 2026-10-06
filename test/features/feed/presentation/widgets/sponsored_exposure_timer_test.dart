import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/sponsored_exposure_timer.dart';

void main() {
  // 记录曝光次数；[valid] 模拟卡片到点复核的结果。
  late int exposures;
  late bool valid;

  setUp(() {
    exposures = 0;
    valid = true;
  });

  void schedule(SponsoredExposureTimer timer) =>
      timer.schedule(stillValid: () => valid, onExposed: () => exposures++);

  test('visibility threshold is 50 percent inclusive', () {
    final timer = SponsoredExposureTimer();
    expect(timer.updateVisibility(0.49), isFalse);
    expect(timer.updateVisibility(0.5), isTrue);
    expect(timer.updateVisibility(1), isTrue);
  });

  test('reports once after one continuous second of visibility', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.6);
      schedule(timer);

      async.elapse(const Duration(milliseconds: 999));
      expect(exposures, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(exposures, 1);

      // 已曝光的广告位再次可见也不重复上报。
      timer.updateVisibility(0.2);
      timer.updateVisibility(0.9);
      schedule(timer);
      async.elapse(const Duration(seconds: 2));
      expect(exposures, 1);
    });
  });

  test('does not start while below the threshold', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.3);
      schedule(timer);
      async.elapse(const Duration(seconds: 2));
      expect(exposures, 0);
    });
  });

  test('dropping below the threshold cancels and restarts the second', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(milliseconds: 700));

      // 中途离屏：计时作废，重新可见后要再满 1 秒。
      timer.updateVisibility(0.1);
      async.elapse(const Duration(milliseconds: 500));
      expect(exposures, 0);

      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(milliseconds: 999));
      expect(exposures, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(exposures, 1);
    });
  });

  test('a second schedule while timing does not restart the clock', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(milliseconds: 600));
      schedule(timer);
      async.elapse(const Duration(milliseconds: 400));
      expect(exposures, 1);
      expect(async.pendingTimers, isEmpty);
    });
  });

  test('cancel stops a pending timer without clearing a report', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(milliseconds: 500));
      timer.cancel();
      async.elapse(const Duration(seconds: 2));
      expect(exposures, 0);

      // 取消后按最近一次可见比例可重新计时；已曝光标记不被 cancel 清除。
      schedule(timer);
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 1);
      timer.cancel();
      schedule(timer);
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 1);
    });
  });

  test('reset allows a new slot to report again', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 1);

      timer.reset();
      schedule(timer);
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 2);
    });
  });

  test('reset cancels a pending timer', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      schedule(timer);
      async.elapse(const Duration(milliseconds: 500));
      timer.reset();
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 0);
    });
  });

  test('a failed stillValid check does not count and can be retimed', () {
    fakeAsync((async) {
      final timer = SponsoredExposureTimer();
      timer.updateVisibility(0.8);
      valid = false;
      schedule(timer);
      async.elapse(const Duration(seconds: 1));
      expect(exposures, 0);

      // 复核失败不标记已曝光，条件恢复后可重新完整计时。
      valid = true;
      schedule(timer);
      async.elapse(const Duration(milliseconds: 999));
      expect(exposures, 0);
      async.elapse(const Duration(milliseconds: 1));
      expect(exposures, 1);
    });
  });
}
