import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/widgets/skeleton_loader.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('SkeletonLoader keeps its child visible while animating',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const Center(
          child: SkeletonLoader(child: Text('加载占位')),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('加载占位'), findsOneWidget);
  });

  testWidgets('PostCardSkeletonList renders the requested skeleton count',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const PostCardSkeletonList(count: 3),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PostCardSkeleton), findsNWidgets(3));
  });

  testWidgets('PostCardSkeletonList defaults to five skeletons',
      (tester) async {
    // 放大视口，确保五个骨架全部进入构建范围。
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        builder: foruiTestBuilder,
        home: const PostCardSkeletonList(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PostCardSkeleton), findsNWidgets(5));
  });
}
