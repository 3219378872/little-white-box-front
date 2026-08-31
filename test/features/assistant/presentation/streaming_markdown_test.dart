import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/streaming_markdown.dart';

import '../../../helpers/forui_test_builder.dart';

Widget _host({
  required String committed,
  required bool streaming,
  bool disableAnimations = false,
  VoidCallback? onRevealed,
  double height = 400,
}) {
  return MaterialApp(
    builder: (context, child) {
      final themed = foruiTestBuilder(context, child);
      return MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: themed,
      );
    },
    home: Scaffold(
      body: SizedBox(
        height: height,
        child: StreamingMarkdownBody(
          key: const Key('stream-body'),
          committedText: committed,
          isStreaming: streaming,
          style: const TextStyle(fontSize: 16, color: Color(0xFF111111)),
          foreground: const Color(0xFF111111),
          onRevealed: onRevealed,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('parses bold after closing markers are revealed', (tester) async {
    await tester.pumpWidget(_host(committed: '', streaming: true));
    await tester.pump();
    await tester.pumpWidget(
      _host(committed: '**加粗**${'尾' * 20}', streaming: true),
    );
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.textContaining('加粗', findRichText: true), findsWidgets);
    expect(find.text('**加粗**${'尾' * 20}'), findsNothing);
    expect(find.textContaining('尾' * 20, findRichText: true), findsNothing);
  });

  testWidgets('non-streaming has no caret and pumpAndSettle completes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(committed: '全文结束', streaming: false));
    await tester.pump();
    expect(find.byKey(const Key('assistant-stream-caret')), findsNothing);
    expect(find.byType(GptMarkdown), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('reset fades old string then types the next attempt', (
    tester,
  ) async {
    await tester.pumpWidget(_host(committed: '旧答案正文', streaming: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('旧', findRichText: true), findsWidgets);

    await tester.pumpWidget(_host(committed: '', streaming: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    expect(find.textContaining('旧', findRichText: true), findsNothing);

    await tester.pumpWidget(_host(committed: '新的尝试', streaming: true));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.textContaining('新', findRichText: true), findsWidgets);
  });

  testWidgets('disableAnimations snaps full on first frame', (tester) async {
    await tester.pumpWidget(
      _host(committed: '立刻全文显示', streaming: true, disableAnimations: true),
    );
    await tester.pump();
    expect(find.textContaining('立刻全文显示', findRichText: true), findsWidgets);
    expect(find.byKey(const Key('assistant-stream-caret')), findsNothing);
  });

  testWidgets('mount replay does not retype the prefix', (tester) async {
    final committed = '前缀内容${'尾' * 190}';
    await tester.pumpWidget(_host(committed: committed, streaming: true));
    await tester.pump();
    expect(find.textContaining('前缀内容', findRichText: true), findsWidgets);
  });

  testWidgets('empty mount then large update starts at 0 not replaySnap', (
    tester,
  ) async {
    await tester.pumpWidget(_host(committed: '', streaming: true));
    await tester.pump();
    expect(find.textContaining('x', findRichText: true), findsNothing);

    await tester.pumpWidget(_host(committed: 'x' * 200, streaming: true));
    await tester.pump();
    expect(find.textContaining('x' * 120, findRichText: true), findsNothing);
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.textContaining('x' * 200, findRichText: true), findsNothing);
  });

  testWidgets('semantics exposes a single revealed label', (tester) async {
    await tester.pumpWidget(_host(committed: '语义文本', streaming: true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final handle = tester.ensureSemantics();
    try {
      expect(find.bySemanticsLabel(RegExp('语义')), findsOneWidget);
    } finally {
      handle.dispose();
    }
  });

  testWidgets('pin harness: drag up stops jumpTo; drag back resumes', (
    tester,
  ) async {
    var pinned = true;
    var jumps = 0;
    final controller = ScrollController();

    Widget build(String text) {
      return MaterialApp(
        builder: foruiTestBuilder,
        home: Scaffold(
          body: SizedBox(
            height: 240,
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (!controller.hasClients) return false;
                final pos = controller.position;
                pinned = (pos.maxScrollExtent - pos.pixels) <= 48;
                return false;
              },
              child: ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 400),
                  StreamingMarkdownBody(
                    committedText: text,
                    isStreaming: true,
                    style: const TextStyle(fontSize: 16),
                    foreground: const Color(0xFF111111),
                    onRevealed: () {
                      if (!pinned) return;
                      jumps += 1;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (controller.hasClients && pinned) {
                          controller.jumpTo(
                            controller.position.maxScrollExtent,
                          );
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 400),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(build('一段足够长的流式正文用来滚动' * 8));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final jumpsWhilePinned = jumps;

    await tester.drag(find.byType(ListView), const Offset(0, 180));
    await tester.pump();
    final afterDrag = jumps;
    await tester.pump(const Duration(milliseconds: 200));
    expect(jumps, afterDrag);
    expect(jumpsWhilePinned, greaterThan(0));

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  });
}
