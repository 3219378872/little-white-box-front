import 'dart:math';

String newIdempotencyKey([int length = 16]) {
  final random = Random.secure();
  return List.generate(
    length,
    (_) => random.nextInt(36).toRadixString(36),
  ).join();
}
