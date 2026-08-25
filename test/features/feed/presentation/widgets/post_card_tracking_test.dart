import 'package:flutter/material.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/behavior/application/behavior_tracker.dart';
import 'package:xiaobaihe_app/features/feed/data/feed_models.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/post_card.dart';
import 'package:xiaobaihe_app/features/interaction/data/interaction_repository.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    // 回调默认 500ms 节流；测试中归零以便 pump 即时触发。
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('requires 50 percent visibility for one continuous second', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final tracker = _RecordingTracker();
    var top = 570.0;
    late StateSetter updateHost;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [behaviorTrackerProvider.overrideWithValue(tracker)],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Stack(
                children: [
                  Positioned(
                    top: top,
                    left: 0,
                    right: 0,
                    child: PostCard(
                      key: const ValueKey('tracked-card'),
                      post: post,
                      recommendationContext: trackingContext,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await pumpPolling(tester, const Duration(milliseconds: 1200));
    expect(tracker.actions.where((action) => action == 'exposure'), isEmpty);

    updateHost(() => top = 0);
    await tester.pump();
    await pumpPolling(tester, const Duration(milliseconds: 900));
    expect(tracker.actions.where((action) => action == 'exposure'), isEmpty);
    await pumpPolling(tester, const Duration(milliseconds: 200));
    expect(
      tracker.actions.where((action) => action == 'exposure'),
      hasLength(1),
    );
  });

  testWidgets('ends dwell when its feed tab becomes inactive', (tester) async {
    final tracker = _RecordingTracker();
    var active = true;
    late StateSetter updateHost;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [behaviorTrackerProvider.overrideWithValue(tracker)],
        child: MaterialApp(
          builder: foruiTestBuilder,
          home: StatefulBuilder(
            builder: (context, setState) {
              updateHost = setState;
              return Scaffold(
                body: PostCard(
                  post: post,
                  recommendationContext: trackingContext,
                  trackingActive: active,
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    await pumpPolling(tester, const Duration(milliseconds: 1100));
    expect(tracker.actions, contains('exposure'));

    updateHost(() => active = false);
    await tester.pump();
    await tester.pump();

    expect(tracker.actions, contains('dwell'));
    expect(tracker.dwellDurations, hasLength(1));
  });

  testWidgets('records click before navigating to the post', (tester) async {
    final tracker = _RecordingTracker();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PostCard(post: post, recommendationContext: trackingContext),
          ),
        ),
        GoRoute(path: '/post/:id', builder: (_, _) => const Text('详情页')),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [behaviorTrackerProvider.overrideWithValue(tracker)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tracked post'));
    await tester.pumpAndSettle();

    expect(tracker.actions, contains('click'));
    expect(find.text('详情页'), findsOneWidget);
  });

  testWidgets('records like only after the interaction succeeds', (
    tester,
  ) async {
    await setTokens(
      Tokens(
        accessToken: mockAccessTokenForUser(1),
        accessExpire: 0,
        refreshToken: '',
        refreshExpire: 0,
        refreshAfter: 0,
      ),
    );
    final tracker = _RecordingTracker();
    final interactions = _RecordingInteractionRepository();
    final container = ProviderContainer(
      overrides: [
        behaviorTrackerProvider.overrideWithValue(tracker),
        postCardInteractionRepositoryProvider.overrideWithValue(interactions),
      ],
    );
    addTearDown(container.dispose);
    container.read(authNotifierProvider);
    for (
      var i = 0;
      i < 20 && container.read(authNotifierProvider).isLoading;
      i++
    ) {
      await tester.pump();
    }

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: PostCard(post: post, recommendationContext: trackingContext),
          ),
        ),
        GoRoute(path: '/post/:id', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('post-like-7')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(interactions.likeCalls, 1);
    expect(tracker.actions, isNot(contains('like')));
  });
}

Future<void> pumpPolling(WidgetTester tester, Duration duration) async {
  final ticks = duration.inMilliseconds ~/ 100;
  for (var i = 0; i < ticks; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final remainder = duration.inMilliseconds % 100;
  if (remainder > 0) {
    await tester.pump(Duration(milliseconds: remainder));
  }
}

final post = PostItem(
  id: 7,
  authorId: 2,
  authorName: 'Author',
  authorAvatar: '',
  title: 'Tracked post',
  content: 'Content',
  images: [],
  tags: [],
  status: 1,
  viewCount: 10,
  likeCount: 2,
  isLiked: false,
  isFavorited: false,
  favoriteCount: 0,
  commentCount: 1,
  revision: 1,
  createdAt: 1700000000,
);

const trackingContext = FeedRecommendationContext(
  requestId: 'request-1',
  scene: 'home',
  position: 3,
  recallSource: 'itemcf',
  modelVersion: 'rank-v1',
  experimentId: 'exp-a',
);

class _RecordingTracker implements BehaviorTracker {
  final List<String> actions = [];
  final List<Duration> dwellDurations = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> trackExposure(
    Object postId,
    FeedRecommendationContext context,
  ) async {
    actions.add('exposure');
    return true;
  }

  @override
  Future<void> trackClick(
    Object postId,
    FeedRecommendationContext context,
  ) async => actions.add('click');

  @override
  Future<void> trackDwell(
    Object postId,
    FeedRecommendationContext context,
    Duration duration,
  ) async {
    actions.add('dwell');
    dwellDurations.add(duration);
  }
}

class _RecordingInteractionRepository extends InteractionRepository {
  int likeCalls = 0;

  @override
  Future<void> likeTarget(Object targetId, int targetType) async => likeCalls++;
}
