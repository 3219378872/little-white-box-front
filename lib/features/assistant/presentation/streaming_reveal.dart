import 'dart:math' as math;

import 'package:characters/characters.dart';

/// 文本变化后打字机应如何处理：extend 继续逐字露出；reset 正文被清空
/// （response_reset），淡出后从头开始；replaySnap 挂载时已有长文本，只重放末尾；
/// snapFull 不流式或减少动画时立即显示全部。
enum RevealSignal { extend, reset, replaySnap, snapFull }

/// 挂载时已提交文本达到该字素数就改用 replaySnap，避免从头逐字重放。
const coldStartReplayGraphemes = 80;

/// replaySnap 时仍以打字机方式露出的末尾字素数。
const tailTypewriterGraphemes = 80;

/// 基础露出速度（字素/秒）。
const baseGps = 28.0;

/// 积压追赶预算：提速到能在该时长内露完当前积压。
const lagBudgetSeconds = 0.3;

// 判断行级 Markdown 结构：代码围栏行，以及能结束稳定块的标题、列表项与表格分隔行。
final _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
final _atxLine = RegExp(r'^ {0,3}#{1,6} .+');
final _listLine = RegExp(r'^ {0,3}(?:[-*+]|\d+[.)]) ');
final _tableSepLine = RegExp(r'^ {0,3}\|?\s*:?-{3,}');

/// 已露出文本的切分：[stablePrefix] 结构已闭合、可按完整 Markdown 渲染；
/// [pendingTail] 仍在增长；[tailIsFence] 表示尾部是未闭合的代码围栏。
class MarkdownRevealSplit {
  const MarkdownRevealSplit({
    required this.stablePrefix,
    required this.pendingTail,
    required this.tailIsFence,
  });

  final String stablePrefix;
  final String pendingTail;
  final bool tailIsFence;
}

/// 首次挂载时的处理方式。
RevealSignal classifyMount({
  required String committed,
  required bool isStreaming,
  required bool reduceMotion,
}) {
  if (!isStreaming || reduceMotion) return RevealSignal.snapFull;
  if (committed.characters.length >= coldStartReplayGraphemes) {
    return RevealSignal.replaySnap;
  }
  return RevealSignal.extend;
}

/// 已提交文本更新时的处理方式：由非空变为空视为 reset。
RevealSignal classifyUpdate({
  required String previousCommitted,
  required String nextCommitted,
  required bool isStreaming,
  required bool reduceMotion,
}) {
  if (!isStreaming || reduceMotion) return RevealSignal.snapFull;
  if (nextCommitted.isEmpty && previousCommitted.isNotEmpty) {
    return RevealSignal.reset;
  }
  return RevealSignal.extend;
}

/// 两个字素序列的最长公共前缀长度，用于正文被改写时回退光标。
int longestCommonPrefixGraphemes(List<String> a, List<String> b) {
  final n = math.min(a.length, b.length);
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return i;
}

/// 打字机的纯状态：按字素缓存已提交文本，[revealedCount] 是已露出的字素数，
/// [lockedGps] 是当前锁定速度，[carry] 累积不足一个字素的进度。
class StreamingRevealController {
  String _committed = '';
  List<String> graphemes = const [];
  int revealedCount = 0;
  double lockedGps = baseGps;
  double carry = 0;
  bool isStreaming = true;
  bool reduceMotion = false;

  String get committed => _committed;

  /// 当前速度高于基础速度，正在追赶积压。
  bool get isCatchingUp => lockedGps > baseGps + 1e-6;

  /// 按积压锁定速度：不低于基础速度，且能在 [lagBudgetSeconds] 内追平。
  void lockGps({required int backlog}) {
    if (backlog <= 0) {
      lockedGps = baseGps;
      return;
    }
    lockedGps = math.max(baseGps, backlog / lagBudgetSeconds);
  }

  /// 文本变化时重建字素缓存（按字素切分，避免截断 emoji 等组合字符）。
  void rebuildGraphemeCache(String next) {
    if (next == _committed) return;
    _committed = next;
    graphemes = next.characters.map((g) => g).toList(growable: false);
  }

  /// 当前已露出的文本。
  String revealedString() => graphemes.take(revealedCount).join();

  /// 光标回到开头并恢复基础速度。
  void resetCursor() {
    revealedCount = 0;
    carry = 0;
    lockGps(backlog: 0);
  }

  /// 按 [signal] 吸收新的已提交文本；reset 只更新缓存，光标由外层在淡出后重置。
  void applyCommitted(String next, RevealSignal signal) {
    final previousGraphemes = graphemes;
    rebuildGraphemeCache(next);
    final grew = graphemes.length > previousGraphemes.length;
    switch (signal) {
      case RevealSignal.reset:
        return;
      case RevealSignal.snapFull:
        revealedCount = graphemes.length;
        carry = 0;
        lockGps(backlog: 0);
        return;
      case RevealSignal.replaySnap:
        revealedCount = math.max(0, graphemes.length - tailTypewriterGraphemes);
        carry = 0;
        lockGps(backlog: graphemes.length - revealedCount);
        return;
      // 正文被改写时光标退回公共前缀；文本增长时按新积压重新锁速。
      case RevealSignal.extend:
        final lcp = longestCommonPrefixGraphemes(previousGraphemes, graphemes);
        revealedCount = math.min(
          revealedCount,
          math.min(lcp, graphemes.length),
        );
        if (grew) {
          lockGps(backlog: graphemes.length - revealedCount);
        }
        return;
    }
  }

  /// 按经过时长推进光标；不流式或减少动画时直接露出全部。
  void onTick(Duration elapsed) {
    if (elapsed <= Duration.zero) return;
    if (!isStreaming || reduceMotion) {
      revealedCount = graphemes.length;
      carry = 0;
      lockedGps = baseGps;
      return;
    }
    final backlog = graphemes.length - revealedCount;
    if (backlog <= 0) {
      carry = 0;
      lockedGps = baseGps;
      return;
    }
    carry += elapsed.inMicroseconds / 1e6 * lockedGps;
    final step = carry.floor();
    carry -= step;
    revealedCount += math.min(backlog, step);
  }
}

/// 把已露出文本切成稳定前缀与增长中的尾部：未闭合的围栏或公式优先（取更靠前者），
/// 其次在最后一个空行处切开，再次是最后一个换行前的那行为标题、列表项或表格
/// 分隔行时在该换行处切开；都不满足时整段作为尾部。
MarkdownRevealSplit splitMarkdownReveal(String revealed) {
  final fence = _unclosedFence(revealed);
  final math = _unclosedMath(revealed);
  if (fence != null && math != null) {
    return fence.stablePrefix.length <= math.stablePrefix.length ? fence : math;
  }
  if (fence != null) return fence;
  if (math != null) return math;

  final para = revealed.lastIndexOf('\n\n');
  if (para >= 0) {
    return MarkdownRevealSplit(
      stablePrefix: revealed.substring(0, para + 2),
      pendingTail: revealed.substring(para + 2),
      tailIsFence: false,
    );
  }

  final nl = revealed.lastIndexOf('\n');
  if (nl > 0) {
    final prevStart = revealed.lastIndexOf('\n', nl - 1) + 1;
    final prevLine = revealed.substring(prevStart, nl);
    if (_atxLine.hasMatch(prevLine) ||
        _listLine.hasMatch(prevLine) ||
        _tableSepLine.hasMatch(prevLine)) {
      return MarkdownRevealSplit(
        stablePrefix: revealed.substring(0, nl + 1),
        pendingTail: revealed.substring(nl + 1),
        tailIsFence: false,
      );
    }
  }

  return MarkdownRevealSplit(
    stablePrefix: '',
    pendingTail: revealed,
    tailIsFence: false,
  );
}

// 逐行跟踪代码围栏：关闭行须用同种字符、长度不短于开启行且没有信息串；
// 仍未关闭时从开启行切开。
MarkdownRevealSplit? _unclosedFence(String revealed) {
  var openerStart = -1;
  var openerChar = '';
  var openerLen = 0;
  var i = 0;
  while (i <= revealed.length) {
    final lineEnd = i >= revealed.length
        ? revealed.length
        : revealed.indexOf('\n', i);
    final end = lineEnd < 0 ? revealed.length : lineEnd;
    final line = revealed.substring(i, end);
    final match = _fenceLine.firstMatch(line);
    if (match != null) {
      final ticks = match.group(1)!;
      final char = ticks[0];
      final len = ticks.length;
      final info = match.group(2) ?? '';
      if (openerStart < 0) {
        openerStart = i;
        openerChar = char;
        openerLen = len;
      } else if (char == openerChar &&
          len >= openerLen &&
          info.trim().isEmpty) {
        openerStart = -1;
        openerChar = '';
        openerLen = 0;
      }
    }
    if (lineEnd < 0 || end >= revealed.length) break;
    i = end + 1;
  }
  if (openerStart < 0) return null;
  return MarkdownRevealSplit(
    stablePrefix: revealed.substring(0, openerStart),
    pendingTail: revealed.substring(openerStart),
    tailIsFence: true,
  );
}

// 查找未闭合的块级公式：成对之外多出的 $$（跳过转义）或未匹配的 \[，取更靠前者。
MarkdownRevealSplit? _unclosedMath(String revealed) {
  final dollars = <int>[];
  for (var i = 0; i < revealed.length - 1; i++) {
    if (revealed[i] == '\\') {
      i++;
      continue;
    }
    if (revealed[i] == r'$' && revealed[i + 1] == r'$') {
      dollars.add(i);
      i++;
    }
  }
  var dollarStart = -1;
  if (dollars.length.isOdd) {
    dollarStart = dollars.last;
  }

  var bracketStart = -1;
  var openCount = 0;
  for (var i = 0; i < revealed.length - 1; i++) {
    if (revealed[i] == '\\' && revealed[i + 1] == '[') {
      if (openCount == 0) bracketStart = i;
      openCount++;
      i++;
      continue;
    }
    if (revealed[i] == '\\' && revealed[i + 1] == ']' && openCount > 0) {
      openCount--;
      if (openCount == 0) bracketStart = -1;
      i++;
    }
  }
  if (openCount == 0) bracketStart = -1;

  final candidates = <int>[
    if (dollarStart >= 0) dollarStart,
    if (bracketStart >= 0) bracketStart,
  ];
  if (candidates.isEmpty) return null;
  final start = candidates.reduce(math.min);
  return MarkdownRevealSplit(
    stablePrefix: revealed.substring(0, start),
    pendingTail: revealed.substring(start),
    tailIsFence: false,
  );
}
