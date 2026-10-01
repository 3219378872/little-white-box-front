import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/behavior/application/behavior_tracker.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    resetMockState();
    setApiClient(MockHttpClient());
  });

  Future<void> pumpFeed(
    WidgetTester tester, {
    AdsRepository? adsRepository,
    BehaviorTracker? tracker,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 4000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      AppProviderScope(
        overrides: [
          if (adsRepository != null)
            adsRepositoryProvider.overrideWithValue(adsRepository),
          if (tracker != null)
            behaviorTrackerProvider.overrideWithValue(tracker),
        ],
        child: const MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('mock ads render after their anchored natural posts', (
    tester,
  ) async {
    await pumpFeed(tester);

    expect(find.text('社区限定桌搭套装上新'), findsOneWidget);
    expect(find.text('在浏览器里写代码'), findsOneWidget);
    expect(find.text('广告'), findsNWidgets(2));
    final firstAd = tester.getTopLeft(find.text('社区限定桌搭套装上新')).dy;
    final secondAd = tester.getTopLeft(find.text('在浏览器里写代码')).dy;
    expect(firstAd, lessThan(secondAd));
    await settle(tester);
  });

  testWidgets('a malformed slot is dropped while posts still load', (
    tester,
  ) async {
    mockSponsoredMalformed = true;
    await pumpFeed(tester);

    expect(find.text('社区限定桌搭套装上新'), findsOneWidget);
    expect(find.text('在浏览器里写代码'), findsNothing);
    expect(find.text('探店｜藏在巷子里的宝藏面馆'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('hide removes the ad and a failure restores it', (tester) async {
    final tracker = _HideRecorder();
    await pumpFeed(
      tester,
      adsRepository: _FailingHideRepository(),
      tracker: tracker,
    );

    final menu = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('ad-menu-'),
    );
    await tester.tap(menu.first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('ad-hide')));
    await tester.pump();

    expect(find.text('社区限定桌搭套装上新'), findsNothing);
    expect(find.text('隐藏失败，广告已恢复'), findsNothing);
    await settle(tester);
    expect(find.text('社区限定桌搭套装上新'), findsOneWidget);
    expect(find.text('隐藏失败，广告已恢复'), findsOneWidget);
    expect(tracker.hides, isEmpty);
    await settle(tester);
  });

  testWidgets('a successful hide keeps the ad removed', (tester) async {
    final tracker = _HideRecorder();
    await pumpFeed(tester, tracker: tracker);
    final menu = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('ad-menu-'),
    );

    await tester.tap(menu.first);
    await settle(tester);
    await tester.tap(find.byKey(const Key('ad-hide')));
    await settle(tester);

    expect(find.text('社区限定桌搭套装上新'), findsNothing);
    expect(find.text('在浏览器里写代码'), findsOneWidget);
    expect(tracker.hides, ['ad:7001:3']);
  });
}

class _FailingHideRepository extends AdsRepository {
  _FailingHideRepository() : super(identityStore: ClientIdentityStore());

  @override
  Future<void> hideAd(Object adId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    throw Exception('offline');
  }
}

class _HideRecorder implements BehaviorTracker {
  final List<String> hides = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> trackExposure(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async => true;

  @override
  Future<void> trackClick(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async {}

  @override
  Future<void> trackHide(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async => hides.add('$targetType:$targetId:${context.position}');

  @override
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  ) async {}
}
