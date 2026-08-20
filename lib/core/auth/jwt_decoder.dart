import 'dart:convert';

import '../api/json_int64.dart';

/// 解析 JWT payload（不验签，只解内容）。
/// token 必须是标准三段式 "header.payload.signature"。
/// 解析失败返回 null。
Map<String, dynamic>? decodeJwtPayload(String token) {
  if (token.isEmpty) return null;
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final normalized = base64Url.normalize(parts[1]);
    final decoded = utf8.decode(base64Url.decode(normalized));
    final json = decodeApiJson(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

/// 从 token 的 payload 中提取 userId。
/// 前提：后端保证 JWT payload 含有字段 `userId`。
/// 失败返回 null。
Object? extractUserIdFromToken(String token) {
  final payload = decodeJwtPayload(token);
  final raw = payload?['userId'];
  if (!jsonInt64IsPositive(raw)) return null;
  return raw is String || raw is num ? raw : jsonInt64Id(raw);
}
