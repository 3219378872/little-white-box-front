import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/search/presentation/search_highlight.dart';

void main() {
  const mark = TextStyle(fontWeight: FontWeight.w700);

  List<(String, bool)> flatten(List<InlineSpan> spans) => [
    for (final span in spans.cast<TextSpan>())
      (span.text!, identical(span.style, mark)),
  ];

  test('parses em markup and keeps other markup literal', () {
    expect(flatten(parseEmHighlight('a<em>b</em>c <b>d</b>', mark)), [
      ('a', false),
      ('b', true),
      ('c <b>d</b>', false),
    ]);
  });

  test('strips unbalanced em tags', () {
    expect(flatten(parseEmHighlight('x</em>y<em>', mark)), [('xy', false)]);
  });

  test('highlights keywords case-insensitively in original casing', () {
    expect(flatten(highlightKeyword('Flutter 与 flutter', 'FLUTTER', mark)), [
      ('Flutter', true),
      (' 与 ', false),
      ('flutter', true),
    ]);
  });

  test('blank keywords return the text unchanged', () {
    expect(flatten(highlightKeyword('手机', '  ', mark)), [('手机', false)]);
  });
}
