import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/router/app_router.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/assistant_page.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';
import 'package:xiaobaihe_app/features/auth/presentation/login_page.dart';
import 'package:xiaobaihe_app/features/feed/presentation/feed_page.dart';
import 'package:xiaobaihe_app/features/message/application/message_notifiers.dart';
import 'package:xiaobaihe_app/features/message/data/message_models.dart';
import 'package:xiaobaihe_app/features/message/data/message_repository.dart';
import 'package:xiaobaihe_app/features/message/presentation/conversations_page.dart';
import 'package:xiaobaihe_app/features/message/presentation/message_thread_page.dart';
import 'package:xiaobaihe_app/features/search/presentation/search_page.dart';
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

  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required String location,
    required double width,
    MessageDataSource? unreadSource,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (context, state, child) =>
              MainShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/feed', builder: (_, _) => const FeedPage()),
            GoRoute(
              path: '/search',
              builder: (_, _) => const SizedBox.expand(),
            ),
            GoRoute(
              path: '/messages',
              builder: (_, _) => const SizedBox.expand(),
            ),
            GoRoute(
              path: '/messages/assistant',
              builder: (_, _) => const SizedBox.expand(),
            ),
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
        overrides: [
          if (unreadSource != null)
            unreadSummaryProvider.overrideWith(
              (ref) => UnreadSummaryNotifier(repository: unreadSource),
            ),
        ],
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

  testWidgets('MainShell renders five mobile navigation destinations', (
    tester,
  ) async {
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
    expect(find.text('搜索'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
    expect(find.text('Assistant'), findsNothing);
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
    expect(items, hasLength(5));
    expect(items[0].selected, isTrue);
    expect(items.skip(1).every((item) => !item.selected), isTrue);
  });

  testWidgets('selects the desktop destination from the current route', (
    tester,
  ) async {
    final router = await pumpShell(tester, location: '/feed', width: 1280);

    List<bool> selection() => tester
        .widgetList<FSidebarItem>(find.byType(FSidebarItem))
        .map((item) => item.selected)
        .toList();

    expect(selection(), [true, false, false, false, false]);

    router.go('/search');
    await tester.pump();
    expect(selection(), [false, true, false, false, false]);

    router.go('/messages');
    await tester.pump();
    expect(selection(), [false, false, true, false, false]);

    router.go('/messages/assistant');
    await tester.pump();
    expect(selection(), [false, false, true, false, false]);

    router.go('/post/new');
    await tester.pump();
    expect(selection(), [false, false, false, true, false]);

    router.go('/profile');
    await tester.pump();
    expect(selection(), [false, false, false, false, true]);
  });

  testWidgets('hides primary navigation on mobile secondary routes', (
    tester,
  ) async {
    await pumpShell(tester, location: '/post/1', width: 390);

    expect(find.byType(FSidebar), findsNothing);
    expect(find.byType(FBottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides stale message navigation after opening Assistant', (
    tester,
  ) async {
    await pumpShell(tester, location: '/messages/assistant', width: 390);

    expect(find.byType(FSidebar), findsNothing);
    expect(find.byType(FBottomNavigationBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens Assistant from messages without retaining mobile navigation',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await setTokens(
        Tokens(
          accessToken: mockAccessTokenForUser(1),
          accessExpire: 0,
          refreshToken: '',
          refreshExpire: 0,
          refreshAfter: 0,
        ),
      );
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
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      router.go('/messages');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ConversationsPage), findsOneWidget);
      expect(find.byType(FBottomNavigationBar), findsOneWidget);

      await tester.tap(find.byKey(const Key('assistant-pinned-thread')));
      for (var i = 0; i < 16; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(
        router.routeInformationProvider.value.uri.path,
        '/messages/assistant',
      );
      expect(find.byType(AssistantPage), findsOneWidget);
      expect(find.byType(FBottomNavigationBar), findsNothing);
      expect(find.text('Assistant'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the message unread count in navigation', (tester) async {
    await pumpShell(
      tester,
      location: '/feed',
      width: 390,
      unreadSource: _RouterMessageSource(
        unread: const UnreadSummary(messageUnread: 12),
      ),
    );

    expect(find.text('12'), findsOneWidget);
  });

  testWidgets('desktop sidebar destinations share the same item box', (
    tester,
  ) async {
    await pumpShell(tester, location: '/feed', width: 1280);

    _expectSidebarItemsAligned(tester);
  });

  testWidgets('desktop message item stays aligned with an unread badge', (
    tester,
  ) async {
    await pumpShell(
      tester,
      location: '/feed',
      width: 1280,
      unreadSource: _RouterMessageSource(
        unread: const UnreadSummary(messageUnread: 12),
      ),
    );

    expect(find.text('12'), findsOneWidget);
    _expectSidebarItemsAligned(tester);
  });

  testWidgets('keeps search public for an anonymous user', (tester) async {
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
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    router.go('/search');
    await tester.pump();

    expect(router.routeInformationProvider.value.uri.path, '/search');
    expect(find.byType(SearchPage), findsOneWidget);
  });

  testWidgets('parses message thread route data and rejects invalid links', (
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
    final source = _RouterMessageSource();
    final container = ProviderContainer(
      overrides: [messageRepositoryProvider.overrideWithValue(source)],
    );
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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    router.go('/search');
    await tester.pump();
    expect(find.byType(SearchPage), findsOneWidget);

    router.go(
      '/messages/8?targetUserId=7&targetUserName=${Uri.encodeQueryComponent('Target user')}',
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final page = tester.widget<MessageThreadPage>(
      find.byType(MessageThreadPage),
    );
    expect(page.conversationId, '8');
    expect(page.targetUserId, '7');
    expect(page.targetUserName, 'Target user');
    expect(source.markedConversationIds, ['8']);

    router.go('/messages/8');
    await tester.pump();
    await tester.pump();
    expect(find.byType(ConversationsPage), findsOneWidget);
  });

  Future<(ProviderContainer, GoRouter)> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    return (container, router);
  }

  testWidgets(
    'auth refresh after a pushed login page does not replace it with feed',
    (tester) async {
      final (container, router) = await pumpApp(tester);

      router.push('/auth/login');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LoginPage), findsOneWidget);

      await container
          .read(authNotifierProvider.notifier)
          .onLoginSuccess(1, mockAccessTokenForUser(1));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(LoginPage), findsOneWidget);
      expect(container.read(authNotifierProvider).isAuthenticated, isTrue);
    },
  );

  testWidgets(
    'password login from a pushed login page opens feed',
    (tester) async {
      final (_, router) = await pumpApp(tester);

      router.push('/auth/login');
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(LoginPage), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsWidgets);
      await tester.enterText(fields.at(0), 'admin');
      await tester.enterText(fields.at(1), '123456');
      await tester.tap(find.widgetWithText(FButton, '登录').first);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(FeedPage), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, '/feed');
    },
  );
}

void _expectSidebarItemsAligned(WidgetTester tester) {
  final items = find.byType(FSidebarItem);
  expect(items, findsNWidgets(5));
  final rects = [for (var i = 0; i < 5; i++) tester.getRect(items.at(i))];
  final first = rects.first;
  for (final rect in rects.skip(1)) {
    expect(rect.height, closeTo(first.height, 0.5));
    expect(rect.width, closeTo(first.width, 0.5));
    expect(rect.left, closeTo(first.left, 0.5));
  }
}

class _RouterMessageSource implements MessageDataSource {
  final UnreadSummary unread;
  final List<Object> markedConversationIds = [];

  _RouterMessageSource({this.unread = const UnreadSummary()});

  @override
  Future<UnreadSummary> getUnreadSummary() async => unread;

  @override
  Future<ConversationPage> getConversations({
    int page = 1,
    int pageSize = 20,
  }) async => const ConversationPage(conversations: [], total: 0);

  @override
  Future<MessagePage> getMessages({
    required Object conversationId,
    Object lastId = 0,
    int pageSize = 20,
  }) async => const MessagePage(messages: [], hasMore: false);

  @override
  Future<void> markConversationRead(Object conversationId) async {
    markedConversationIds.add(conversationId);
  }

  @override
  Future<Object> sendMessage(SendMessageCommand command) async => 1;
}
