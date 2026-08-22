import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/idempotency.dart';

void main() {
  test('generates url-safe lowercase base36 keys of the requested length',
      () {
    expect(newIdempotencyKey(), hasLength(16));
    expect(newIdempotencyKey(8), hasLength(8));

    final pattern = RegExp(r'^[0-9a-z]+$');
    for (var i = 0; i < 50; i++) {
      expect(newIdempotencyKey().startsWith(pattern), isTrue);
    }
  });

  test('does not repeat keys across calls', () {
    final seen = <String>{
      for (var i = 0; i < 100; i++) newIdempotencyKey(),
    };
    expect(seen, hasLength(100));
  });
}
