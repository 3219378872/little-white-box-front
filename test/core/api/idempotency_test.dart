import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/idempotency.dart';

void main() {
  test('generates url-safe lowercase base36 keys of the requested length', () {
    expect(newIdempotencyKey(), hasLength(16));
    expect(newIdempotencyKey(8), hasLength(8));

    final pattern = RegExp(r'^[0-9a-z]+$');
    for (var i = 0; i < 50; i++) {
      expect(newIdempotencyKey().startsWith(pattern), isTrue);
    }
  });

  test('does not repeat keys across calls', () {
    final seen = <String>{for (var i = 0; i < 100; i++) newIdempotencyKey()};
    expect(seen, hasLength(100));
  });

  test('prefixed request ids keep prefix, timestamp radix and byte length', () {
    final message = newPrefixedRequestId('message');
    expect(message, matches(RegExp(r'^message-[0-9a-f]+-[0-9a-f]{32}$')));

    final assistant = newPrefixedRequestId('assistant', randomBytes: 12);
    expect(assistant, matches(RegExp(r'^assistant-[0-9a-f]+-[0-9a-f]{24}$')));

    final before = DateTime.now().microsecondsSinceEpoch;
    final upload = newPrefixedRequestId('upload', timestampRadix: 10);
    final parts = upload.split('-');
    expect(parts, hasLength(3));
    expect(parts.first, 'upload');
    expect(int.parse(parts[1]), greaterThanOrEqualTo(before));
    expect(parts[2], matches(RegExp(r'^[0-9a-f]{32}$')));
  });
}
