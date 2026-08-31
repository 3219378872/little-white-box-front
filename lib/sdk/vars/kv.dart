import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/tokens.dart';

const String _tokenKey = 'tokens';
const String _sessionRevisionKey = 'tokens.session_revision';
const String _payloadRevisionKey = 'session_revision';

Future<void>? _mutationTail;

class SessionTokenSnapshot {
  final Tokens tokens;
  final int revision;

  const SessionTokenSnapshot({required this.tokens, required this.revision});

  bool hasSameSession(SessionTokenSnapshot other) => revision == other.revision;

  bool hasSameRefreshCredential(SessionTokenSnapshot other) {
    return hasSameSession(other) &&
        tokens.refreshToken == other.tokens.refreshToken;
  }

  bool hasSameCredentials(SessionTokenSnapshot other) {
    return hasSameRefreshCredential(other) &&
        tokens.accessToken == other.tokens.accessToken;
  }
}

/// Starts a new login session. Token rotation must use the conditional replace
/// below so a response from an older account cannot overwrite a newer login.
Future<SessionTokenSnapshot> startTokenSession(Tokens tokens) {
  return _mutate(() async {
    final preferences = await SharedPreferences.getInstance();
    final revision = _nextRevision(preferences);
    await _writeRevision(preferences, revision);
    await _writeTokens(preferences, tokens, revision);
    return SessionTokenSnapshot(tokens: tokens, revision: revision);
  });
}

/// A direct write represents a new login session, not a token refresh.
Future<bool> setTokens(Tokens tokens) async {
  await startTokenSession(tokens);
  return true;
}

Future<SessionTokenSnapshot?> replaceTokensIfRefreshCredentialMatches(
  SessionTokenSnapshot expected,
  Tokens tokens,
) {
  return _mutate(() async {
    final preferences = await SharedPreferences.getInstance();
    final current = _readSnapshot(preferences);
    if (current == null || !current.hasSameRefreshCredential(expected)) {
      return null;
    }
    await _writeTokens(preferences, tokens, current.revision);
    return SessionTokenSnapshot(tokens: tokens, revision: current.revision);
  });
}

Future<bool> removeTokensIfCredentialsMatch(SessionTokenSnapshot expected) {
  return _removeIf((current) => current.hasSameCredentials(expected));
}

Future<bool> removeTokensIfRefreshCredentialMatches(
  SessionTokenSnapshot expected,
) {
  return _removeIf((current) => current.hasSameRefreshCredential(expected));
}

/// Explicit logout always advances the local session revision.
Future<bool> removeTokens() {
  return _mutate(() async {
    final preferences = await SharedPreferences.getInstance();
    final revision = _nextRevision(preferences);
    await _writeRevision(preferences, revision);
    return preferences.remove(_tokenKey);
  });
}

Future<int> getTokenSessionRevision() async {
  final mutation = _mutationTail;
  if (mutation != null) await mutation;
  final preferences = await SharedPreferences.getInstance();
  return preferences.getInt(_sessionRevisionKey) ??
      _payloadRevision(preferences) ??
      0;
}

Future<SessionTokenSnapshot?> getTokenSnapshot() async {
  final mutation = _mutationTail;
  if (mutation != null) await mutation;
  final preferences = await SharedPreferences.getInstance();
  return _readSnapshot(preferences);
}

Future<Tokens?> getTokens() async => (await getTokenSnapshot())?.tokens;

Future<bool> _removeIf(bool Function(SessionTokenSnapshot current) predicate) {
  return _mutate(() async {
    final preferences = await SharedPreferences.getInstance();
    final current = _readSnapshot(preferences);
    if (current == null || !predicate(current)) return false;
    final revision = _nextRevision(preferences);
    await _writeRevision(preferences, revision);
    await preferences.remove(_tokenKey);
    return true;
  });
}

SessionTokenSnapshot? _readSnapshot(SharedPreferences preferences) {
  try {
    final encoded = preferences.getString(_tokenKey);
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    final payload = Map<String, dynamic>.from(decoded);
    final payloadRevision = _integer(payload[_payloadRevisionKey]) ?? 0;
    final currentRevision =
        preferences.getInt(_sessionRevisionKey) ?? payloadRevision;
    if (payloadRevision != currentRevision) return null;
    return SessionTokenSnapshot(
      tokens: Tokens.fromJson(payload),
      revision: currentRevision,
    );
  } catch (_) {
    return null;
  }
}

int? _payloadRevision(SharedPreferences preferences) {
  try {
    final encoded = preferences.getString(_tokenKey);
    if (encoded == null || encoded.isEmpty) return null;
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) return null;
    return _integer(decoded[_payloadRevisionKey]);
  } catch (_) {
    return null;
  }
}

int _nextRevision(SharedPreferences preferences) {
  final current =
      preferences.getInt(_sessionRevisionKey) ??
      _payloadRevision(preferences) ??
      0;
  return current == 0x7fffffff ? 1 : current + 1;
}

Future<void> _writeRevision(SharedPreferences preferences, int revision) async {
  if (!await preferences.setInt(_sessionRevisionKey, revision)) {
    throw StateError('failed to persist token session revision');
  }
}

Future<void> _writeTokens(
  SharedPreferences preferences,
  Tokens tokens,
  int revision,
) async {
  final payload = <String, dynamic>{
    ...tokens.toJson(),
    _payloadRevisionKey: revision,
  };
  if (!await preferences.setString(_tokenKey, jsonEncode(payload))) {
    throw StateError('failed to persist tokens');
  }
}

int? _integer(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

Future<T> _mutate<T>(Future<T> Function() action) {
  final previous = _mutationTail;
  final gate = Completer<void>();
  final tail = gate.future;
  final completer = Completer<T>();
  _mutationTail = tail;

  Future<void> run() async {
    try {
      completer.complete(await action());
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    } finally {
      if (identical(_mutationTail, tail)) _mutationTail = null;
      gate.complete();
    }
  }

  if (previous == null) {
    unawaited(run());
  } else {
    unawaited(previous.then((_) => run()));
  }
  return completer.future;
}
