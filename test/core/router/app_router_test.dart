import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:xiaobaihe_app/core/router/app_router.dart';
import 'package:xiaobaihe_app/features/auth/application/auth_notifier.dart';

void main() {
  testWidgets('MainShell renders 3 navigation destinations', (tester) async {
    final container = ProviderContainer();
    final router = container.read(routerProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('首页'), findsOneWidget);
    expect(find.text('发布'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });
}
