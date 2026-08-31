import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/assistant/presentation/streaming_reveal.dart';

void pump16(StreamingRevealController c, int frames) {
  for (var i = 0; i < frames; i++) {
    c.onTick(const Duration(milliseconds: 16));
  }
}

void main() {
  group('classifyMount / classifyUpdate', () {
    test('empty mount is extend', () {
      expect(
        classifyMount(committed: '', isStreaming: true, reduceMotion: false),
        RevealSignal.extend,
      );
    });

    test('mount with 200 graphemes is replaySnap', () {
      final committed = '汉' * 200;
      expect(
        classifyMount(
          committed: committed,
          isStreaming: true,
          reduceMotion: false,
        ),
        RevealSignal.replaySnap,
      );
    });

    test('update after empty mount with 200 graphemes is extend', () {
      expect(
        classifyUpdate(
          previousCommitted: '',
          nextCommitted: 'a' * 200,
          isStreaming: true,
          reduceMotion: false,
        ),
        RevealSignal.extend,
      );
    });

    test('classifyUpdate never returns replaySnap', () {
      expect(
        classifyUpdate(
          previousCommitted: 'x' * 10,
          nextCommitted: 'x' * 500,
          isStreaming: true,
          reduceMotion: false,
        ),
        RevealSignal.extend,
      );
    });

    test('empty next while streaming is reset', () {
      expect(
        classifyUpdate(
          previousCommitted: 'Answer',
          nextCommitted: '',
          isStreaming: true,
          reduceMotion: false,
        ),
        RevealSignal.reset,
      );
    });

    test('citation-strip contraction is extend not reset', () {
      expect(
        classifyUpdate(
          previousCommitted: 'Answer [p',
          nextCommitted: 'Answer 结论',
          isStreaming: true,
          reduceMotion: false,
        ),
        RevealSignal.extend,
      );
    });

    test('not streaming snaps full', () {
      expect(
        classifyMount(
          committed: 'done',
          isStreaming: false,
          reduceMotion: false,
        ),
        RevealSignal.snapFull,
      );
      expect(
        classifyUpdate(
          previousCommitted: 'a',
          nextCommitted: 'ab',
          isStreaming: false,
          reduceMotion: false,
        ),
        RevealSignal.snapFull,
      );
    });

    test('reduceMotion snaps full', () {
      expect(
        classifyMount(
          committed: 'x' * 9,
          isStreaming: true,
          reduceMotion: true,
        ),
        RevealSignal.snapFull,
      );
    });
  });

  group('StreamingRevealController', () {
    test('does not split emoji or ZWJ graphemes', () {
      final c = StreamingRevealController();
      c.applyCommitted('👨‍👩‍👧‍👦', RevealSignal.extend);
      expect(c.graphemes, ['👨‍👩‍👧‍👦']);
      c.onTick(const Duration(milliseconds: 100));
      expect(c.revealedString(), '👨‍👩‍👧‍👦');
    });

    test('extend keeps revealedCount monotonic when appending', () {
      final c = StreamingRevealController();
      c.applyCommitted('你好', RevealSignal.extend);
      c.onTick(const Duration(milliseconds: 100));
      final first = c.revealedCount;
      expect(first, greaterThan(0));
      c.applyCommitted('你好世界', RevealSignal.extend);
      expect(c.revealedCount, first);
      c.onTick(const Duration(milliseconds: 100));
      expect(c.revealedCount, greaterThanOrEqualTo(first));
    });

    test('base rate about 28 gps', () {
      final c = StreamingRevealController();
      c.applyCommitted('一二三四五六七八', RevealSignal.extend);
      c.lockGps(backlog: 1);
      // After locking to 1 leftover: revealed already 0 and lock used backlog 1
      // Rebuild: applyCommitted locks from full length. Re-lock to 28 for this case.
      c.revealedCount = 0;
      c.lockGps(backlog: 1);
      // backlog is actually 8; force the 28 gps path by locking 1 then
      // revealing via onTick against remaining. Simpler: one 100ms tick at 28.
      c.revealedCount = 0;
      c.lockedGps = baseGps;
      c.carry = 0;
      c.onTick(const Duration(milliseconds: 100));
      expect(c.revealedCount, 2); // 28 * 0.1 = 2.8 → 2
    });

    test('base rate backlog=1 pump16 7 frames reveals 3 or 4', () {
      final c = StreamingRevealController();
      c.applyCommitted('一二三四五六七八九十', RevealSignal.extend);
      c.revealedCount = 0;
      c.lockedGps = baseGps;
      c.carry = 0;
      // After applyCommitted lockGps used backlog=10. Reset to base.
      c.lockedGps = baseGps;
      pump16(c, 7);
      expect(c.revealedCount, inInclusiveRange(3, 4));
    });

    test('linear catch-up empties 50 graphemes in 19 frames of 16ms', () {
      final c = StreamingRevealController();
      c.applyCommitted('汉' * 50, RevealSignal.extend);
      expect(c.revealedCount, 0);
      pump16(c, 19);
      expect(c.revealedCount, 50);
    });

    test('live +500 after typing is extend catch-up not replaySnap', () {
      final c = StreamingRevealController();
      c.applyCommitted('前缀正文', RevealSignal.extend);
      c.onTick(const Duration(milliseconds: 200));
      expect(c.revealedCount, greaterThan(0));
      final signal = classifyUpdate(
        previousCommitted: '前缀正文',
        nextCommitted: '前缀正文${'x' * 500}',
        isStreaming: true,
        reduceMotion: false,
      );
      expect(signal, RevealSignal.extend);
      c.applyCommitted('前缀正文${'x' * 500}', signal);
      pump16(c, 19);
      expect(c.revealedCount, 4 + 500);
    });

    test('empty mount then +200 extends from 0', () {
      final c = StreamingRevealController();
      final mount = classifyMount(
        committed: '',
        isStreaming: true,
        reduceMotion: false,
      );
      c.applyCommitted('', mount);
      expect(c.revealedCount, 0);
      final next = 'z' * 200;
      final update = classifyUpdate(
        previousCommitted: '',
        nextCommitted: next,
        isStreaming: true,
        reduceMotion: false,
      );
      expect(update, RevealSignal.extend);
      c.applyCommitted(next, update);
      expect(c.revealedCount, 0);
      pump16(c, 19);
      expect(c.revealedCount, 200);
    });

    test('mount replaySnap jumps to len-80', () {
      final committed = 'w' * 200;
      final c = StreamingRevealController();
      final signal = classifyMount(
        committed: committed,
        isStreaming: true,
        reduceMotion: false,
      );
      expect(signal, RevealSignal.replaySnap);
      c.applyCommitted(committed, signal);
      expect(c.revealedCount, 120);
    });

    test('snapFull aligns immediately', () {
      final c = StreamingRevealController();
      c.applyCommitted('hello world', RevealSignal.extend);
      c.applyCommitted('hello world', RevealSignal.snapFull);
      expect(c.revealedCount, c.graphemes.length);
    });

    test('reset leaves cursor until resetCursor', () {
      final c = StreamingRevealController();
      c.applyCommitted('hello', RevealSignal.extend);
      c.onTick(const Duration(milliseconds: 200));
      expect(c.revealedCount, greaterThan(0));
      c.applyCommitted('', RevealSignal.reset);
      expect(c.revealedCount, greaterThan(0));
      c.resetCursor();
      expect(c.revealedCount, 0);
    });

    test('strip contraction clamps to LCP without reset', () {
      final c = StreamingRevealController();
      c.applyCommitted('Answer [p', RevealSignal.extend);
      c.revealedCount = 'Answer [p'.characters.length;
      c.applyCommitted('Answer 结论', RevealSignal.extend);
      expect(c.revealedCount, 'Answer '.characters.length);
    });
  });

  group('splitMarkdownReveal', () {
    test('unclosed fence is tailIsFence from opener', () {
      const input = 'intro\n```\ncode';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, 'intro\n');
      expect(split.pendingTail, '```\ncode');
      expect(split.tailIsFence, isTrue);
    });

    test('closed fence goes to prefix via blank line or stays with closer', () {
      const input = '```\ncode\n```\n\nmore';
      final split = splitMarkdownReveal(input);
      expect(split.tailIsFence, isFalse);
      expect(split.stablePrefix, '```\ncode\n```\n\n');
      expect(split.pendingTail, 'more');
    });

    test('4-backtick opener is not closed by 3-backtick', () {
      const input = '````\ncode\n```';
      final split = splitMarkdownReveal(input);
      expect(split.tailIsFence, isTrue);
      expect(split.pendingTail, input);
    });

    test('unclosed emphasis without blank line is 100% tail', () {
      const input = 'hello **bold';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, isEmpty);
      expect(split.pendingTail, input);
      expect(split.tailIsFence, isFalse);
    });

    test('single paragraph with closed bold is 100% tail', () {
      const input = '**加粗** 结论';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, isEmpty);
      expect(split.pendingTail, input);
      expect(split.tailIsFence, isFalse);
    });

    test('unclosed dollar math splits at last opener', () {
      const input = r'pi $$x = 1';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, 'pi ');
      expect(split.pendingTail, r'$$x = 1');
      expect(split.tailIsFence, isFalse);
    });

    test(r'unclosed \[ splits at opener', () {
      const input = r'before \[a + b';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, 'before ');
      expect(split.pendingTail, r'\[a + b');
    });

    test('completed list line promotes on newline', () {
      const input = '- 项目一\n下一';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, '- 项目一\n');
      expect(split.pendingTail, '下一');
    });

    test('single paragraph no blank line is 100% tail', () {
      const input = '只是一段没有空行的中文。';
      final split = splitMarkdownReveal(input);
      expect(split.stablePrefix, isEmpty);
      expect(split.pendingTail, input);
    });

    test('stripped citation text is not a fence', () {
      const input = 'Answer 结论';
      final split = splitMarkdownReveal(input);
      expect(split.tailIsFence, isFalse);
      expect(split.pendingTail, input);
    });
  });
}
