import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setApiClient(MockHttpClient());
  });

  Future<void> pumpFeed(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(builder: foruiTestBuilder, home: FeedPage()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('FeedPage shows 推荐 and 关注 tabs', (tester) async {
    await pumpFeed(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
  });

  testWidgets('anonymous follow tab shows a login-required state', (
    tester,
  ) async {
    await pumpFeed(tester);

    await tester.tap(find.text('关注'));
    await pumpFrames(tester, 4);

    expect(find.text('登录后查看关注动态'), findsOneWidget);
    expect(find.text('关注流功能开发中'), findsNothing);
  });

  testWidgets('authenticated follow tab loads the v2 feed', (tester) async {
    await setTokens(
      Tokens(
        accessToken: mockAccessTokenForUser(1),
        accessExpire: 0,
        refreshToken: '',
        refreshExpire: 0,
        refreshAfter: 0,
      ),
    );
    await pumpFeed(tester);

    await tester.tap(find.text('关注'));
    await pumpFrames(tester, 7);

    expect(find.text('探店｜藏在巷子里的宝藏面馆'), findsOneWidget);
    expect(find.text('关注流功能开发中'), findsNothing);
  });
}

Future<void> pumpFrames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
