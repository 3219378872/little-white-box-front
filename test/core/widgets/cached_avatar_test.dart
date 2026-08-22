import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/cached_avatar.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  Future<FAvatar> pumpAvatar(WidgetTester tester, CachedAvatar avatar) async {
    await tester.pumpWidget(
      MaterialApp(builder: foruiTestBuilder, home: Center(child: avatar)),
    );
    await tester.pump();
    return tester.widget<FAvatar>(find.byType(FAvatar));
  }

  Color? fallbackBackground(FAvatar avatar) =>
      (avatar.style as dynamic).backgroundColor as Color?;

  testWidgets('falls back to the first character of the name', (tester) async {
    await pumpAvatar(tester, const CachedAvatar(name: '小明'));

    expect(find.text('小'), findsOneWidget);
  });

  testWidgets('shows a person icon when no name is available',
      (tester) async {
    await pumpAvatar(tester, const CachedAvatar());

    expect(find.byIcon(FLucideIcons.userRound), findsOneWidget);
  });

  testWidgets('ignores blank names like missing ones', (tester) async {
    await pumpAvatar(tester, const CachedAvatar(name: '   '));

    expect(find.byIcon(FLucideIcons.userRound), findsOneWidget);
  });

  testWidgets('assigns deterministic fallback colors from the name',
      (tester) async {
    final ming = await pumpAvatar(tester, const CachedAvatar(name: '小明'));
    final mingAgain =
        await pumpAvatar(tester, const CachedAvatar(name: '小明'));
    final qiang = await pumpAvatar(tester, const CachedAvatar(name: '强子'));

    expect(fallbackBackground(ming), isNotNull);
    expect(fallbackBackground(mingAgain), fallbackBackground(ming));
    expect(fallbackBackground(qiang), isNot(fallbackBackground(ming)));
  });

  testWidgets('uses an anonymous gray when the name is missing',
      (tester) async {
    final anonymous = await pumpAvatar(tester, const CachedAvatar());

    expect(
      fallbackBackground(anonymous),
      const Color(0xFFE5E7EB),
    );
  });

  testWidgets('sizes the avatar from the radius', (tester) async {
    final avatar = await pumpAvatar(tester, const CachedAvatar(name: '明'));

    expect(avatar.size, 40);
  });
}
