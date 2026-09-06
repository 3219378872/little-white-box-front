import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:xiaobaihe_app/core/theme/app_theme.dart';
import 'package:xiaobaihe_app/core/widgets/app_tag_badge.dart';
import 'package:xiaobaihe_app/core/widgets/skeleton_loader.dart';
import 'package:xiaobaihe_app/features/comment/presentation/widgets/comment_input.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/post_media_preview.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  test('Android reference palette and typography share one owner', () {
    expect(AppTheme.foruiLight.colors.background, const Color(0xFFFFFFFF));
    expect(AppTheme.foruiDark.colors.background, const Color(0xFF101112));
    expect(AppTheme.foruiLight.colors.foreground, const Color(0xFF14191E));
    expect(AppTheme.foruiDark.colors.foreground, const Color(0xFFE1E2E3));
    for (final theme in [AppTheme.foruiLight, AppTheme.foruiDark]) {
      expect(theme.typography.body.md.fontSize, 16);
      expect(theme.typography.display.lg.fontSize, 24);
      expect(theme.typography.body.md.letterSpacing, 0);
      expect(theme.style.shadow, isEmpty);
      expect(theme.tabsStyle.indicatorSize, FTabBarIndicatorSize.label);
    }
  });

  for (final count in [0, 1, 2, 3, 5, 9]) {
    testWidgets('$count images use stable reference geometry at 320px', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: foruiTestBuilder,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 296,
                child: PostMediaPreview(
                  images: List.generate(
                    count,
                    (i) => 'https://example.test/$i.jpg',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final images = find.byType(CachedNetworkImage);
      expect(images, findsNWidgets(count.clamp(0, 3)));
      if (count > 0) {
        final size = tester.getSize(find.byType(PostMediaPreview));
        expect(size.width, 296);
        expect(
          size.height,
          closeTo(
            count == 1 ? 296 * .72 / 1.45 : 296 / (count > 3 ? 2.5 : 3),
            .01,
          ),
        );
      }
      if (count > 3) expect(find.text('共$count张'), findsOneWidget);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'long removable tag and composer fit small screens, dark=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        String? submitted;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            builder: foruiTestBuilder,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 740),
                textScaler: TextScaler.linear(1.6),
              ),
              child: Scaffold(
                body: Column(
                  children: [
                    SizedBox(
                      width: 160,
                      child: AppTagBadge(
                        label: '这是一个需要在窄屏完整保持语义的超长标签',
                        onRemove: () {},
                      ),
                    ),
                    const Spacer(),
                    CommentInput(
                      onSubmit: (value) async => submitted = value,
                      actions: const SizedBox(
                        width: 132,
                        height: 48,
                        child: Text('互动'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(EditableText), '评论内容');
        await tester.pump();
        expect(find.text('互动'), findsNothing);
        await tester.tap(find.bySemanticsLabel('发送评论'));
        await tester.pumpAndSettle();
        expect(submitted, '评论内容');
        expect(find.text('互动'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('skeleton honors reduced motion', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PostCardSkeleton(),
        ),
      ),
    );
    final filter = tester
        .widget<ColorFiltered>(find.byType(ColorFiltered))
        .colorFilter;
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester.widget<ColorFiltered>(find.byType(ColorFiltered)).colorFilter,
      filter,
    );
    expect(tester.binding.transientCallbackCount, 0);
  });
}
