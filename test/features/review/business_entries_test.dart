import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/feed_side_rail.dart';
import 'package:xiaobaihe_app/features/profile/presentation/profile_page.dart';
import 'package:xiaobaihe_app/features/review/application/reviewer_access.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
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

  Future<void> pump(WidgetTester tester, Widget child, {int? user}) async {
    if (user != null) {
      await setTokens(
        Tokens(
          accessToken: mockAccessTokenForUser(user),
          accessExpire: 0,
          refreshToken: '',
          refreshExpire: 0,
          refreshAfter: 0,
        ),
      );
    }
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(body: child),
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
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('reviewers see both business entries in the profile', (
    tester,
  ) async {
    await pump(tester, const BusinessEntries(), user: 1);

    expect(find.text('商业'), findsOneWidget);
    expect(find.byKey(const Key('profile-ads-console')), findsOneWidget);
    expect(find.byKey(const Key('profile-review-workbench')), findsOneWidget);
  });

  testWidgets('other users only see the advertiser console', (tester) async {
    await pump(tester, const BusinessEntries(), user: 2);

    expect(find.byKey(const Key('profile-ads-console')), findsOneWidget);
    expect(find.byKey(const Key('profile-review-workbench')), findsNothing);
  });

  testWidgets('desktop rail hides business entries from anonymous users', (
    tester,
  ) async {
    await pump(tester, const FeedSideRail());

    expect(find.byKey(const Key('feed-rail-ads')), findsNothing);
    expect(find.byKey(const Key('feed-rail-review')), findsNothing);
  });

  testWidgets('desktop rail shows the workbench only to reviewers', (
    tester,
  ) async {
    await pump(tester, const FeedSideRail(), user: 1);

    expect(find.byKey(const Key('feed-rail-ads')), findsOneWidget);
    expect(find.byKey(const Key('feed-rail-review')), findsOneWidget);
  });

  test('only review roles open the workbench', () {
    expect(const ReviewerAccess(active: true, roles: ['qa']).canReview, isTrue);
    expect(
      const ReviewerAccess(active: true, roles: ['policy_admin']).canReview,
      isFalse,
    );
    expect(
      const ReviewerAccess(active: false, roles: ['reviewer']).canReview,
      isFalse,
    );
  });
}
