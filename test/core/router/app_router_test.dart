import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/router/app_router.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setApiClient(MockHttpClient());
  });

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required String location,
    required double width,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
            GoRoute(
              path: '/post/new',
              builder: (_, _) => const SizedBox.expand(),
            ),
            GoRoute(
              path: '/post/:postId',
              builder: (_, _) => const SizedBox.expand(),
            ),
            GoRoute(
              path: '/profile',
              builder: (_, _) => const SizedBox.expand(),
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    return router;
  }

  testWidgets('MainShell renders 3 navigation destinations', (tester) async {
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    addTearDown(container.dispose);

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
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('switches from bottom navigation to sidebar at lg breakpoint', (
    tester,
  ) async {
    await pumpShell(tester, location: '/feed', width: 1023);

    expect(find.byType(FBottomNavigationBar), findsOneWidget);
    expect(find.byType(FSidebar), findsNothing);

    tester.view.physicalSize = const Size(1024, 900);
    await tester.pump();

    expect(find.byType(FBottomNavigationBar), findsNothing);
    expect(find.byType(FSidebar), findsOneWidget);
  });

  testWidgets('uses the tablet content width without stretching the feed', (
    tester,
  ) async {
    await pumpShell(tester, location: '/feed', width: 800);

    expect(tester.getSize(find.byType(FeedPage)).width, 680);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps sidebar on desktop secondary routes', (tester) async {
    await pumpShell(tester, location: '/post/1', width: 1280);

    expect(find.byType(FSidebar), findsOneWidget);
    expect(find.byType(FBottomNavigationBar), findsNothing);
    final items = tester
        .widgetList<FSidebarItem>(find.byType(FSidebarItem))
        .toList();
    expect(items, hasLength(3));
    expect(items[0].selected, isTrue);
    expect(items[1].selected, isFalse);
    expect(items[2].selected, isFalse);
  });

  testWidgets('selects the desktop destination from the current route', (
    tester,
  ) async {
    final router = await pumpShell(tester, location: '/feed', width: 1280);

    List<bool> selection() => tester
        .widgetList<FSidebarItem>(find.byType(FSidebarItem))
        .map((item) => item.selected)
        .toList();

    expect(selection(), [true, false, false]);

    router.go('/post/new');
    await tester.pump();
    expect(selection(), [false, true, false]);

    router.go('/profile');
    await tester.pump();
    expect(selection(), [false, false, true]);
  });

  testWidgets('hides primary navigation on mobile secondary routes', (
    tester,
  ) async {
    await pumpShell(tester, location: '/post/1', width: 390);

    expect(find.byType(FSidebar), findsNothing);
    expect(find.byType(FBottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
