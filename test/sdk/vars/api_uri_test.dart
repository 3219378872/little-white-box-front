import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/sdk/vars/vars.dart';

void main() {
  group('apiUri', () {
    test('keeps gateway paths relative when host is empty', () {
      expect(apiUri('/api/v1/health', host: ''), Uri.parse('/api/v1/health'));
      expect(apiUri('api/v1/health', host: '  '), Uri.parse('/api/v1/health'));
    });

    test('joins an explicit origin without a double slash', () {
      expect(
        apiUri('/api/v1/auth/login', host: 'http://127.0.0.1:8888'),
        Uri.parse('http://127.0.0.1:8888/api/v1/auth/login'),
      );
      expect(
        apiUri('/api/v2/assistant/thread', host: 'http://gateway.test/'),
        Uri.parse('http://gateway.test/api/v2/assistant/thread'),
      );
    });
  });
}
