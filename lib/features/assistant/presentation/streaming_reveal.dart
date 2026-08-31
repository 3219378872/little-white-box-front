import 'dart:math' as math;

import 'package:characters/characters.dart';

enum RevealSignal { extend, reset, replaySnap, snapFull }

const coldStartReplayGraphemes = 80;
const tailTypewriterGraphemes = 80;
const baseGps = 28.0;
const lagBudgetSeconds = 0.3;

final _fenceLine = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
final _atxLine = RegExp(r'^ {0,3}#{1,6} .+');
final _listLine = RegExp(r'^ {0,3}(?:[-*+]|\d+[.)]) ');
final _tableSepLine = RegExp(r'^ {0,3}\|?\s*:?-{3,}');

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

int longestCommonPrefixGraphemes(List<String> a, List<String> b) {
  final n = math.min(a.length, b.length);
  var i = 0;
  while (i < n && a[i] == b[i]) {
    i++;
  }
  return i;
}

class StreamingRevealController {
  String _committed = '';
  List<String> graphemes = const [];
  int revealedCount = 0;
  double lockedGps = baseGps;
  double carry = 0;
  bool isStreaming = true;
  bool reduceMotion = false;

  String get committed => _committed;

  bool get isCatchingUp => lockedGps > baseGps + 1e-6;

  void lockGps({required int backlog}) {
    if (backlog <= 0) {
      lockedGps = baseGps;
      return;
    }
    lockedGps = math.max(baseGps, backlog / lagBudgetSeconds);
  }

  void rebuildGraphemeCache(String next) {
    if (next == _committed) return;
    _committed = next;
    graphemes = next.characters.map((g) => g).toList(growable: false);
  }

  String revealedString() => graphemes.take(revealedCount).join();

  void resetCursor() {
    revealedCount = 0;
    carry = 0;
    lockGps(backlog: 0);
  }

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
