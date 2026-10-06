import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/idempotency.dart';

const _anonymousIdKey = 'behavior.anonymous_id.v1';
const _sessionIdKey = 'behavior.session_id.v1';
const _requestIdKey = 'behavior.request_id.v1';

/// 未登录也稳定的客户端身份，随推荐、广告与行为上报一起发送，供服务端关联同一客户端的请求。
class ClientIdentity {
  final String anonymousId;
  final String sessionId;

  const ClientIdentity({required this.anonymousId, required this.sessionId});
}

/// 在本地偏好中持久化客户端身份与最近一次请求 ID，跨启动复用。
class ClientIdentityStore {
  final Future<SharedPreferences> Function() _preferences;
  final String Function(String prefix) _generateId;
  Future<ClientIdentity>? _identity;

  ClientIdentityStore({
    Future<SharedPreferences> Function()? preferences,
    String Function(String prefix)? generateId,
  }) : _preferences = preferences ?? SharedPreferences.getInstance,
       _generateId = generateId ?? newPrefixedRequestId;

  /// 读取或首次生成匿名 ID 与会话 ID；同一实例内并发调用共享同一个 Future。
  Future<ClientIdentity> loadOrCreate() {
    return _identity ??= _loadOrCreate();
  }

  /// 生成新的请求 ID 并记为最近一次；Feed 刷新时调用以开启新的推荐快照，
  /// 翻页沿用该 ID。
  Future<String> createRequestId() async {
    final preferences = await _preferences();
    final requestId = _generateId('request');
    await preferences.setString(_requestIdKey, requestId);
    return requestId;
  }

  /// 返回最近一次请求 ID，尚未生成过时新建。
  Future<String> loadOrCreateRequestId() async {
    final preferences = await _preferences();
    final stored = preferences.getString(_requestIdKey)?.trim() ?? '';
    if (stored.isNotEmpty) return stored;
    return createRequestId();
  }

  /// 生成一次性的行为事件客户端 ID，重试与回执对账时据此识别同一事件。
  String createEventId() => _generateId('event');

  // 依次读取或生成匿名 ID 与会话 ID。
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

  // 偏好中已有非空值则复用，否则按前缀生成并写回。
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

/// 全局共享的客户端身份存储，保证同一进程只生成一套身份。
final clientIdentityStoreProvider = Provider<ClientIdentityStore>((ref) {
  return ClientIdentityStore();
});
