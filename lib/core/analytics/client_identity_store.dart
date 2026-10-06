import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/idempotency.dart';

const _anonymousIdKey = 'behavior.anonymous_id.v1';
const _sessionIdKey = 'behavior.session_id.v1';
const _requestIdKey = 'behavior.request_id.v1';

class ClientIdentity {
  final String anonymousId;
  final String sessionId;

  const ClientIdentity({required this.anonymousId, required this.sessionId});
}

class ClientIdentityStore {
  final Future<SharedPreferences> Function() _preferences;
  final String Function(String prefix) _generateId;
  Future<ClientIdentity>? _identity;

  ClientIdentityStore({
    Future<SharedPreferences> Function()? preferences,
    String Function(String prefix)? generateId,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _generateId = generateId ?? newPrefixedRequestId;

  Future<ClientIdentity> loadOrCreate() {
    return _identity ??= _loadOrCreate();
  }

  Future<String> createRequestId() async {
    final preferences = await _preferences();
    final requestId = _generateId('request');
    await preferences.setString(_requestIdKey, requestId);
    return requestId;
  }

  Future<String> loadOrCreateRequestId() async {
    final preferences = await _preferences();
    final stored = preferences.getString(_requestIdKey)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    return createRequestId();
  }

  String createEventId() => _generateId('event');

  Future<ClientIdentity> _loadOrCreate() async {
    final preferences = await _preferences();
    final anonymousId = await _loadOrCreateValue(
      preferences,
      _anonymousIdKey,
      'anonymous',
    );
    final sessionId = await _loadOrCreateValue(
      preferences,
      _sessionIdKey,
      'session',
    );
    return ClientIdentity(anonymousId: anonymousId, sessionId: sessionId);
  }

  Future<String> _loadOrCreateValue(
    SharedPreferences preferences,
    String key,
    String prefix,
  ) async {
    final stored = preferences.getString(key)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final value = _generateId(prefix);
    await preferences.setString(key, value);
    return value;
  }
}

final clientIdentityStoreProvider = Provider<ClientIdentityStore>((ref) {
  return ClientIdentityStore();
});
