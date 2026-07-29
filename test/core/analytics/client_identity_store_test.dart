import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists anonymous and session identity across store instances',
    () async {
      var sequence = 0;
      String generate(String prefix) => '$prefix-${++sequence}';

      final firstStore = ClientIdentityStore(generateId: generate);
      final first = await firstStore.loadOrCreate();
      final cached = await firstStore.loadOrCreate();
      final restored = await ClientIdentityStore(
        generateId: generate,
      ).loadOrCreate();

      expect(first.anonymousId, 'anonymous-1');
      expect(first.sessionId, 'session-2');
      expect(identical(first, cached), isTrue);
      expect(restored.anonymousId, first.anonymousId);
      expect(restored.sessionId, first.sessionId);
      expect(sequence, 2);
    },
  );

  test('creates and persists a new recommendation request id', () async {
    var sequence = 0;
    final store = ClientIdentityStore(
      generateId: (prefix) => '$prefix-${++sequence}',
    );

    expect(await store.createRequestId(), 'request-1');
    expect(await store.loadOrCreateRequestId(), 'request-1');
    expect(await store.createRequestId(), 'request-2');
    expect(await store.loadOrCreateRequestId(), 'request-2');
  });
}
