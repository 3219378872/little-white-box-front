import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/feed/presentation/widgets/post_card.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

import '../../../../helpers/forui_test_builder.dart';

void main() {
  testWidgets('PostCard renders title and stats', (tester) async {
    final post = PostItem(
      id: 1,
      authorId: 1,
      authorName: 'TestUser',
      authorAvatar: '',
      title: 'Hello World',
      content: 'This is a test post',
      images: [],
      tags: ['test'],
      likeCount: 42,
      commentCount: 5,
      viewCount: 100,
      createdAt: 1700000000,
    );

    await tester.pumpWidget(
      MaterialApp(builder: foruiTestBuilder, home: Scaffold(body: PostCard(post: post))),
    );

    expect(find.text('Hello World'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });

  testWidgets('PostCard shows image count overlay for multiple images',
      (tester) async {
    final post = PostItem(
      id: 1,
      authorId: 1,
      authorName: 'TestUser',
      authorAvatar: '',
      title: '',
      content: 'Post with images',
      images: ['http://a.jpg', 'http://b.jpg', 'http://c.jpg'],
      tags: [],
      likeCount: 0,
      commentCount: 0,
      viewCount: 0,
      createdAt: 1700000000,
    );

    await tester.pumpWidget(
      MaterialApp(builder: foruiTestBuilder, home: Scaffold(body: PostCard(post: post))),
    );

    expect(find.text('+2'), findsOneWidget);
  });
}
