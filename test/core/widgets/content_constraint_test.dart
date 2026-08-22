import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/content_constraint.dart';

void main() {
  Future<double> builtWidth(
    WidgetTester tester, {
    required double surfaceWidth,
    required double maxWidth,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: surfaceWidth,
            child: ContentConstraint(
              maxWidth: maxWidth,
              child: const ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    return tester
        .getSize(
          find.descendant(
            of: find.byType(ContentConstraint),
            matching: find.byType(ColoredBox),
          ),
        )
        .width;
  }

  testWidgets('caps the inner width on wide screens', (tester) async {
    final width = await builtWidth(
      tester,
      surfaceWidth: 1200,
      maxWidth: 600,
    );

    expect(width, 600);
  });

  testWidgets('keeps the full width on narrow screens', (tester) async {
    final width = await builtWidth(
      tester,
      surfaceWidth: 360,
      maxWidth: 600,
    );

    expect(width, 360);
  });

  testWidgets('applies horizontal padding inside the constraint',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: ContentConstraint(
              horizontalPadding: 16,
              child: ColoredBox(color: Colors.red),
            ),
          ),
        ),
      ),
    );

    final constrained = tester.widget<ConstrainedBox>(
      find.descendant(
        of: find.byType(ContentConstraint),
        matching: find.byType(ConstrainedBox),
      ),
    );
    expect(constrained.constraints.maxWidth, 600);
    expect(
      tester
          .getSize(
            find.descendant(
              of: find.byType(ContentConstraint),
              matching: find.byType(ColoredBox),
            ),
          )
          .width,
      400 - 32,
    );
  });
}
