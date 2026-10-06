import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/image_mime.dart';

void main() {
  final jpeg = [0xFF, 0xD8, 0xFF, 0xE0];
  final png = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  final webp = utf8.encode('RIFF\x00\x00\x00\x00WEBP');

  test('prefers the file extension case-insensitively', () {
    expect(detectImageMime('a.JPG', png), 'image/jpeg');
    expect(detectImageMime('a.jpeg', const []), 'image/jpeg');
    expect(detectImageMime('a.Png', const []), 'image/png');
    expect(detectImageMime('a.webp', const []), 'image/webp');
  });

  test('sniffs jpeg, png and webp headers without a usable extension', () {
    expect(detectImageMime('photo', jpeg), 'image/jpeg');
    expect(detectImageMime('photo.bin', png), 'image/png');
    expect(detectImageMime('photo', webp), 'image/webp');
  });

  test('returns null for unknown or truncated headers', () {
    expect(detectImageMime('anim.gif', utf8.encode('GIF89a')), isNull);
    expect(
      detectImageMime('photo', utf8.encode('RIFF\x00\x00\x00\x00WAVE')),
      isNull,
    );
    expect(detectImageMime('photo', utf8.encode('RIFF')), isNull);
    expect(detectImageMime('photo', const []), isNull);
  });

  test('upload mime falls back to jpeg when detection fails', () {
    expect(inferImageMime('photo', webp), 'image/webp');
    expect(inferImageMime('anim.gif', utf8.encode('GIF89a')), 'image/jpeg');
  });
}
