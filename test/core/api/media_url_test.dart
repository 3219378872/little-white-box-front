import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/media_url.dart';

void main() {
  test('keeps absolute image urls unchanged', () {
    const url = 'https://cdn.example.com/a.png';

    expect(resolveImageUrl(url, host: 'http://gateway.test'), url);
  });

  test('joins site-relative image paths to the gateway origin', () {
    expect(
      resolveImageUrl('/xbh-media/a.png', host: 'http://gateway.test/'),
      'http://gateway.test/xbh-media/a.png',
    );
    expect(resolveImageUrl('/xbh-media/a.png', host: ''), '/xbh-media/a.png');
  });
}
