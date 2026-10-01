import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/behavior/application/behavior_tracker.dart';
import 'package:xiaobaihe_app/features/behavior/data/behavior_event.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/data/sponsored_parser.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/sponsored_ad_card.dart';

import '../../../../helpers/forui_test_builder.dart';

final slot = parseSponsoredSlots(
  [
    {
      'slotId': 'slot-4',
      'afterPosition': 4,
      'ad': {
        'adId': 7001,
        'revision': 2,
        'advertiserName': '小白盒周边店',
        'title': '桌搭套装上新',
        'body': '演示广告',
        'cta': '去看看',
        'landingUrl': 'https://shop.example.com/desk',
        'landingDomain': 'shop.example.com',
        'disclosure': 'sponsored',
        'why': {'market': 'US', 'scene': 'home', 'personalized': false},
      },
    },
  ],
  requestId: 'request-1',
  scene: 'home',
).slots.single;

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  Future<_RecordingTracker> pumpCard(
    WidgetTester tester, {
    ThemeMode themeMode = ThemeMode.light,
    Future<void> Function()? onHide,
    Future<void> Function(String reason)? onReport,
    List<Uri>? opened,
  }) async {
    final tracker = _RecordingTracker();
    await tester.pumpWidget(
      AppProviderScope(
        overrides: [behaviorTrackerProvider.overrideWithValue(tracker)],
        child: MaterialApp(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeMode,
          builder: foruiTestBuilder,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SponsoredAdCard(
                slot: slot,
                onHide: onHide ?? () async {},
                onReport: onReport ?? (_) async {},
                openExternal: (uri) async {
                  opened?.add(uri);
                  return true;
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return tracker;
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('discloses the advertiser and landing domain (${mode.name})', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpCard(tester, themeMode: mode);

      expect(find.text('广告'), findsOneWidget);
      expect(find.text('小白盒周边店'), findsOneWidget);
      expect(find.text('shop.example.com'), findsOneWidget);
      expect(find.text('去看看'), findsOneWidget);
      expect(find.bySemanticsLabel('广告，由 小白盒周边店 推广'), findsOneWidget);
      expect(find.byKey(Key('ad-menu-${slot.key}')), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets('reports ad exposure after one visible second only once', (
    tester,
  ) async {
    final tracker = await pumpCard(tester);

    await tester.pump(const Duration(milliseconds: 900));
    expect(tracker.calls, isEmpty);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));

    expect(tracker.calls, ['exposure:ad:7001:4']);
  });

  testWidgets('CTA records the click and opens the reviewed landing page', (
    tester,
  ) async {
    final opened = <Uri>[];
    final tracker = await pumpCard(tester, opened: opened);

    await tester.tap(find.byKey(Key('ad-cta-${slot.key}')));
    await tester.pump();

    expect(tracker.calls.first, 'click:ad:7001:4');
    expect(opened, [Uri.parse('https://shop.example.com/desk')]);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('menu explains why and hides the ad', (tester) async {
    var hidden = 0;
    final tracker = await pumpCard(tester, onHide: () async => hidden++);
    tracker.calls.clear();

    await tester.tap(find.byKey(Key('ad-menu-${slot.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-why')));
    await tester.pumpAndSettle();
    expect(find.text('为什么看到这条广告'), findsOneWidget);
    expect(find.text('US'), findsOneWidget);
    expect(find.text('首页推荐'), findsOneWidget);
    expect(find.text('否'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('ad-menu-${slot.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-hide')));
    await tester.pumpAndSettle();

    expect(hidden, 1);
    // The feed records the hide only after the server accepts it.
    expect(tracker.calls.where((call) => call.startsWith('hide')), isEmpty);
  });

  _reportTests();
}

// FX-101：举报入口只收结构化原因；关闭面板不提交，选择原因即提交且不上报行为事件。
void _reportTests() {
  testWidgets('menu reports the ad with a structured reason', (tester) async {
    final reasons = <String>[];
    final tracker = _RecordingTracker();
    await tester.pumpWidget(
      AppProviderScope(
        overrides: [behaviorTrackerProvider.overrideWithValue(tracker)],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SponsoredAdCard(
                slot: slot,
                onHide: () async {},
                onReport: (reason) async => reasons.add(reason),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(Key('ad-menu-${slot.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-report')));
    await tester.pumpAndSettle();
    expect(find.text('举报这条广告'), findsOneWidget);
    expect(find.text('诈骗或欺诈'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(reasons, isEmpty, reason: 'dismissing the sheet must not report');

    await tester.tap(find.byKey(Key('ad-menu-${slot.key}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-report')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ad-report-reason-scam')));
    await tester.pumpAndSettle();

    expect(reasons, ['scam']);
    expect(find.text('举报这条广告'), findsNothing);
    expect(
      tracker.calls.where((call) => !call.startsWith('exposure')),
      isEmpty,
    );
    await tester.pump(const Duration(seconds: 2));
  });
}

class _RecordingTracker implements BehaviorTracker {
  final List<String> calls = [];

  @override
  Future<void> initialize() async {}

  void _record(
    String action,
    Object id,
    FeedRecommendationContext context,
    String type,
  ) => calls.add('$action:$type:$id:${context.position}');

  @override
  Future<bool> trackExposure(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async {
    _record('exposure', targetId, context, targetType);
    return true;
  }

  @override
  Future<void> trackClick(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async => _record('click', targetId, context, targetType);

  @override
  Future<void> trackHide(
    Object targetId,
    FeedRecommendationContext context, {
    String targetType = behaviorTargetPost,
  }) async => _record('hide', targetId, context, targetType);

  @override
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  ) async => _record('dwell', postId, context, behaviorTargetPost);
}
