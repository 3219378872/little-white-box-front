import 'package:flutter/widgets.dart';

final _emTag = RegExp(r'<em>(.*?)</em>', caseSensitive: false, dotAll: true);
final _anyTag = RegExp(r'</?em>', caseSensitive: false);

/// Turns the server highlight markup (`<em>` around matches) into spans.
///
/// Only `<em>` is recognized; the text is never parsed as HTML, so other
/// markup stays literal. Unbalanced tags are stripped.
List<InlineSpan> parseEmHighlight(String source, TextStyle mark) {
  final spans = <InlineSpan>[];
  var cursor = 0;
  for (final match in _emTag.allMatches(source)) {
    if (match.start > cursor) {
      final plain = source
          .substring(cursor, match.start)
          .replaceAll(_anyTag, '');
      if (plain.isNotEmpty) spans.add(TextSpan(text: plain));
    }
    final hit = match.group(1)!.replaceAll(_anyTag, '');
    if (hit.isNotEmpty) spans.add(TextSpan(text: hit, style: mark));
    cursor = match.end;
  }
  if (cursor < source.length) {
    final rest = source.substring(cursor).replaceAll(_anyTag, '');
    if (rest.isNotEmpty) spans.add(TextSpan(text: rest));
  }
  return spans;
}

/// Marks case-insensitive occurrences of [keyword] in [text].
List<InlineSpan> highlightKeyword(String text, String keyword, TextStyle mark) {
  var needle = keyword.trim();
  if (needle.isEmpty) return [TextSpan(text: text)];
  // Lower-casing can change length for a few scripts; fall back to exact
  // matching so indices always refer to the original text.
  var haystack = text.toLowerCase();
  if (haystack.length == text.length &&
      needle.toLowerCase().length == needle.length) {
    needle = needle.toLowerCase();
  } else {
    haystack = text;
  }
  final spans = <InlineSpan>[];
  var cursor = 0;
  while (true) {
    final index = haystack.indexOf(needle, cursor);
    if (index < 0) break;
    if (index > cursor) {
      spans.add(TextSpan(text: text.substring(cursor, index)));
    }
    spans.add(
      TextSpan(text: text.substring(index, index + needle.length), style: mark),
    );
    cursor = index + needle.length;
  }
  if (cursor < text.length) spans.add(TextSpan(text: text.substring(cursor)));
  return spans;
}
