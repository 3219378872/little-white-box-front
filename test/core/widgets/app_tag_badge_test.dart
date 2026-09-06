import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/app_tag_badge.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('renders a CJK label with bounded wrapping', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(child: AppTagBadge(label: '美食探店')),
      ),
    );

    final text = tester.widget<Text>(find.text('美食探店'));
    final badgeWidth = tester.getSize(find.byType(AppTagBadge)).width;

    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(badgeWidth, greaterThan(50));
  });

  testWidgets('exposes and invokes the remove action', (tester) async {
    var removed = false;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Center(
          child: AppTagBadge(label: '美食', onRemove: () => removed = true),
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('移除标签 美食'));
    await tester.pumpAndSettle();

    expect(removed, isTrue);
  });
}
