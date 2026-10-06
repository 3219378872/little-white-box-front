import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/collections/unique_by.dart';

void main() {
  test('uniqueBy keeps the first item for each key in order', () {
    final items = [(1, 'a'), (2, 'b'), (1, 'c'), (3, 'd'), (2, 'e')];

    expect(uniqueBy(items, (item) => item.$1), [(1, 'a'), (2, 'b'), (3, 'd')]);
  });

  test('appendUniqueBy keeps current intact and drops repeated additions', () {
    final current = [(1, 'a'), (2, 'b')];
    final additions = [(2, 'x'), (3, 'c'), (3, 'y'), (4, 'd')];

    expect(appendUniqueBy(current, additions, (item) => item.$1), [
      (1, 'a'),
      (2, 'b'),
      (3, 'c'),
      (4, 'd'),
    ]);
  });
}
