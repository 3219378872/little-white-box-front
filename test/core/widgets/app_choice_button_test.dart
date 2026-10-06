import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/widgets/app_choice_button.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool selected}) {
    return tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Center(
          child: AppChoiceButton(
            label: '中国大陆',
            selected: selected,
            onPress: () {},
          ),
        ),
      ),
    );
  }

  testWidgets('marks the selected option with a check', (tester) async {
    await pump(tester, selected: true);

    final button = tester.widget<FButton>(find.byType(FButton));
    expect(button.variant, FButtonVariant.secondary);
    expect(find.byIcon(FLucideIcons.check), findsOneWidget);
  });

  testWidgets('renders unselected options as outline without a check', (
    tester,
  ) async {
    await pump(tester, selected: false);

    final button = tester.widget<FButton>(find.byType(FButton));
    expect(button.variant, FButtonVariant.outline);
    expect(find.byIcon(FLucideIcons.check), findsNothing);
  });

  testWidgets('forwards taps to onPress', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: Center(
          child: AppChoiceButton(
            label: '金融',
            selected: false,
            onPress: () => pressed++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('金融'));
    await tester.pumpAndSettle();
    expect(pressed, 1);
  });
}
