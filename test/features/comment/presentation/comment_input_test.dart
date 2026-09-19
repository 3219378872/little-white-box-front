import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/comment/presentation/widgets/comment_input.dart';

import '../../../helpers/forui_test_builder.dart';

void main() {
  for (final editDuringSend in [false, true]) {
    testWidgets(
      'comment completion ${editDuringSend ? 'preserves the next draft' : 'clears the submitted draft'}',
      (tester) async {
        final pending = Completer<void>();
        String? submitted;
        await tester.pumpWidget(
          MaterialApp(
            builder: foruiTestBuilder,
            home: Scaffold(
              body: CommentInput(
                onSubmit: (text) {
                  submitted = text;
                  return pending.future;
                },
              ),
            ),
          ),
        );
        await tester.enterText(find.byType(EditableText), '  first comment  ');
        await tester.tap(find.bySemanticsLabel('发送评论'));
        await tester.pump();
        if (editDuringSend) {
          await tester.enterText(find.byType(EditableText), 'next draft');
        }
        pending.complete();
        await tester.pumpAndSettle();
        expect(submitted, 'first comment');
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          editDuringSend ? 'next draft' : '',
        );
      },
    );
  }
}
