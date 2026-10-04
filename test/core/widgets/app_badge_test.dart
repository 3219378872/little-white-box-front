import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/app_badge.dart';

import '../../helpers/forui_test_builder.dart';

Future<void> _announceFontsChange(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.system.name,
    SystemChannels.system.codec.encodeMessage(<String, Object>{
      'type': 'fontsChange',
    }),
    (_) {},
  );
  await tester.pump();
}

void main() {
  testWidgets('remeasures the label after system fonts change', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: AppBadge(child: Text('回扫'))),
      ),
    );
    final before = tester.renderObject<RenderParagraph>(find.text('回扫'));

    await _announceFontsChange(tester);

    // A stale paragraph keeps the intrinsic width measured before a web
    // fallback font loaded; a new render object measures from scratch.
    final after = tester.renderObject<RenderParagraph>(find.text('回扫'));
    expect(identical(before, after), isFalse);
    expect(find.text('回扫'), findsOneWidget);
  });

  testWidgets('keeps the subtree untouched without a fonts change', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: AppBadge(child: Text('占位'))),
      ),
    );
    final before = tester.renderObject<RenderParagraph>(find.text('占位'));

    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: AppBadge(child: Text('占位'))),
      ),
    );

    expect(
      identical(before, tester.renderObject<RenderParagraph>(find.text('占位'))),
      isTrue,
    );
  });

  testWidgets('stops listening once disposed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: AppBadge(child: Text('质检'))),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    await _announceFontsChange(tester);

    expect(tester.takeException(), isNull);
  });
}
