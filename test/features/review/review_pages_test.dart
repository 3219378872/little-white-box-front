import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/review/presentation/review_evidence.dart';
import 'package:xiaobaihe_app/features/review/presentation/review_home_page.dart';
import 'package:xiaobaihe_app/features/review/presentation/review_task_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetMockState();
    setApiClient(MockHttpClient());
  });

  Future<void> signIn(int userId) => setTokens(
    Tokens(
      accessToken: mockAccessTokenForUser(userId),
      accessExpire: 0,
      refreshToken: '',
      refreshExpire: 0,
      refreshAfter: 0,
    ),
  );

  String claim({String purpose = ''}) {
    final response = dispatchResponse(
      'POST',
      '/api/v2/review/tasks/claim',
      jsonEncode({'purpose': purpose}),
      headers: {'Authorization': 'Bearer ${mockAccessTokenForUser(1)}'},
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['task'] as Map)['taskId'].toString();
  }

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => page),
        GoRoute(path: '/review', builder: (_, _) => const SizedBox.shrink()),
        GoRoute(
          path: '/review/tasks/:taskId',
          builder: (_, state) => Text('task ${state.pathParameters['taskId']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      AppProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('non reviewers see the forbidden page', (tester) async {
    await signIn(2);
    await pump(tester, const ReviewHomePage());

    expect(find.text('没有审核权限'), findsOneWidget);
    expect(find.byKey(const Key('review-claim-next')), findsNothing);
  });

  testWidgets('reviewers see their scope and queue buckets', (tester) async {
    await signIn(1);
    await pump(tester, const ReviewHomePage());

    expect(find.text('我的授权'), findsOneWidget);
    expect(find.byKey(const Key('review-claim-next')), findsOneWidget);
    expect(find.text('首次审核'), findsOneWidget);
    expect(find.text('质检'), findsOneWidget);
    expect(find.textContaining('待处理 3 单'), findsOneWidget);
  });

  testWidgets('QA tasks are labelled and show the original decision', (
    tester,
  ) async {
    await signIn(1);
    final taskId = claim(purpose: 'qa');
    await pump(tester, ReviewTaskPage(taskId: taskId));

    expect(find.byKey(const Key('review-purpose-qa')), findsOneWidget);
    expect(find.byKey(const Key('review-original-decision')), findsOneWidget);
    expect(find.text('通过（机审）'), findsOneWidget);
    expect(
      find.byKey(const Key('review-stage-placeholder-ranker')),
      findsOneWidget,
    );
    expect(
      find.textContaining('shop.example.com', findRichText: true),
      findsWidgets,
    );

    await tester.tap(find.byKey(const Key('review-submit')));
    await settle(tester);

    expect(find.text('结论已提交'), findsOneWidget);
    expect(find.byKey(const Key('review-submit')), findsNothing);
  });

  testWidgets('reject needs a policy code before submit is enabled', (
    tester,
  ) async {
    await signIn(1);
    final taskId = claim(purpose: 'initial');
    await pump(tester, ReviewTaskPage(taskId: taskId));

    await tester.tap(find.byKey(const Key('review-verdict-reject')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('review-submit')));
    await settle(tester);
    expect(find.text('结论已提交'), findsNothing);

    await tester.tap(find.byKey(const Key('review-code-MISLEADING.CLAIM')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('review-submit')));
    await settle(tester);

    expect(find.text('结论已提交'), findsOneWidget);
    expect(find.textContaining('承诺或夸大效果'), findsWidgets);
  });

  testWidgets('a superseded task explains itself and returns to the queue', (
    tester,
  ) async {
    await signIn(1);
    claim(purpose: 'initial');
    final superseded = claim(purpose: 'initial');
    await pump(tester, ReviewTaskPage(taskId: superseded));

    await tester.tap(find.byKey(const Key('review-submit')));
    await settle(tester);

    expect(find.byKey(const Key('review-closure-superseded')), findsOneWidget);
    expect(find.text('返回队列'), findsOneWidget);
    expect(find.byKey(const Key('review-submit')), findsNothing);
  });

  testWidgets('a lost lease is reported without resubmitting', (tester) async {
    await signIn(1);
    claim(purpose: 'initial');
    claim(purpose: 'initial');
    final lost = claim(purpose: 'initial');
    await pump(tester, ReviewTaskPage(taskId: lost));

    await tester.tap(find.byKey(const Key('review-renew')));
    await settle(tester);

    expect(find.byKey(const Key('review-closure-leaseLost')), findsOneWidget);
    expect(find.byKey(const Key('review-renew')), findsNothing);
  });

  testWidgets('warns when less than two minutes of the lease remain', (
    tester,
  ) async {
    await signIn(1);
    final taskId = claim(purpose: 'initial');
    await pump(
      tester,
      ReviewTaskPage(
        taskId: taskId,
        now: () => DateTime.now().add(const Duration(minutes: 9)),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final remaining = tester.widget<Text>(
      find.byKey(const Key('review-lease-remaining')),
    );
    expect(remaining.data, startsWith('持有剩余 '));
    expect(find.text('持有剩余不足 2 分钟，请续期或尽快提交'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('claim next opens the leased task', (tester) async {
    await signIn(1);
    await pump(tester, const ReviewHomePage());

    await tester.tap(find.byKey(const Key('review-claim-next')));
    await settle(tester);

    expect(find.text('task 9001'), findsOneWidget);
  });

  testWidgets('claiming from an empty queue explains there is no task', (
    tester,
  ) async {
    await signIn(1);
    for (var i = 0; i < 4; i++) {
      claim();
    }
    await pump(tester, const ReviewHomePage());

    expect(find.text('授权范围内暂无待处理任务'), findsOneWidget);
    await tester.tap(find.byKey(const Key('review-claim-next')));
    await settle(tester);

    expect(find.text('队列暂无可领取的任务'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('evidence loads snapshot media through the review endpoint', (
    tester,
  ) async {
    await signIn(1);
    final task = ReviewTaskItem.fromJson({
      'taskId': 9001,
      'bizType': 'advertiser_qualification',
      'purpose': 'initial',
      'status': 'claimed',
      'snapshotJson': jsonEncode({
        'texts': {'name': 'Acme', 'markets': 'US,DE'},
        'media': [
          {'mediaId': 1, 'sha256': 'a'},
        ],
        'market': 'DE',
        'language': 'de',
        'qualifications': [
          {
            'market': 'DE',
            'industry': 'FINANCIAL',
            'documentMediaId': 2,
            'validUntilMs': 4102444800000,
          },
        ],
      }),
      'stages': <Object>[],
    });
    await pump(
      tester,
      SingleChildScrollView(child: ReviewEvidence(task: task)),
    );

    expect(find.text('主体名称'), findsOneWidget);
    expect(find.text('Acme'), findsOneWidget);
    expect(find.textContaining('有效期至 2100-01-01'), findsOneWidget);
    expect(find.bySemanticsLabel('送审素材 1'), findsOneWidget);
    expect(find.bySemanticsLabel('送审素材 2'), findsOneWidget);
    expect(find.text('没有机审记录'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
