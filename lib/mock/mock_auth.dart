part of 'mock_router.dart';

// 登录：loginType 2 为验证码登录，任意合法手机号与非空验证码都登录为用户 1；
// 其余按用户名密码校验，`admin` 是用户 1 的别名。
Map<String, dynamic> _login(Map<String, dynamic> body) {
  final loginType = (body['loginType'] as num?)?.toInt() ?? 0;
  if (loginType == 2) {
    final phone = body['phone']?.toString() ?? '';
    final code = body['verifyCode']?.toString() ?? '';
    if (!_isPhone(phone) || code.isEmpty) {
      throw const _MockBiz(400, 2, '参数错误');
    }
    return {...mockTokenPairForUser(1), 'userId': 1};
  }
  final username = body['username']?.toString() ?? '';
  final password = body['password']?.toString() ?? '';
  if (username.isEmpty || password.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  final lookup = username == 'admin' ? 'xiaobaige' : username;
  Map<String, dynamic>? user;
  for (final candidate in _users.values) {
    if (candidate['username'] == lookup) {
      user = candidate;
      break;
    }
  }
  if (user == null) throw const _MockBiz(404, 1001, '用户不存在');
  if (_passwords[lookup] != password) {
    throw const _MockBiz(401, 1003, '密码错误');
  }
  return {
    ...mockTokenPairForUser((user['id'] as num).toInt()),
    'userId': user['id'],
  };
}

// 注册：校验用户名长度、密码强度、手机号格式与重名，成功后直接签发令牌。
Map<String, dynamic> _register(Map<String, dynamic> body) {
  final username = body['username']?.toString() ?? '';
  final password = body['password']?.toString() ?? '';
  final phone = body['phone']?.toString() ?? '';
  if (username.isEmpty && phone.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (username.isNotEmpty) {
    final length = username.runes.length;
    if (length < 6 || length > 50) {
      throw const _MockBiz(400, 2, '用户名长度应在6~50之间');
    }
    _assertPasswordStrength(password);
  }
  if (phone.isNotEmpty && !_isPhone(phone)) {
    throw const _MockBiz(400, 2, '非法的手机号');
  }
  if (username.isNotEmpty && _passwords.containsKey(username)) {
    throw const _MockBiz(409, 1002, '用户已存在');
  }
  final id = _nextUserId++;
  final resolvedName = username.isEmpty ? 'user$id' : username;
  _users[id] = {
    'id': id,
    'username': resolvedName,
    'nickname': resolvedName,
    'avatarUrl': '',
    'bio': '',
    'level': 1,
    'followerCount': 0,
    'followingCount': 0,
    'postCount': 0,
    'favoritesVisible': true,
  };
  _passwords[resolvedName] = password.isEmpty ? mockDevPassword : password;
  _personalizationEnabled[id] = true;
  return {...mockTokenPairForUser(id), 'userId': id};
}

/// 凭 refreshToken 换取全新令牌对；一次性轮换，重放已用令牌按无效处理。
Map<String, dynamic> _refreshTokens(Map<String, dynamic> body) {
  final refreshToken = body['refreshToken']?.toString() ?? '';
  if (refreshToken.isEmpty) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  if (_usedRefreshTokens.contains(refreshToken)) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  final payload = _decodeJwtPayload(refreshToken);
  if (payload == null) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  final exp = payload['exp'];
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  if (exp is num && exp.toInt() > 0 && exp.toInt() < nowSec) {
    throw const _MockBiz(401, 1004, '登录已过期，请重新登录');
  }
  final userId = payload['userId'];
  if (userId is! num || userId.toInt() <= 0) {
    throw const _MockBiz(401, 1005, '登录状态无效，请重新登录');
  }
  _usedRefreshTokens.add(refreshToken);
  return mockTokenPairForUser(userId.toInt());
}

// 发送验证码只校验手机号与用途，不真正发送；验证码在登录/注册时不做比对。
MockRouterResponse _sendVerifyCode(Map<String, dynamic> body) {
  final phone = body['phone']?.toString() ?? '';
  final type = (body['type'] as num?)?.toInt() ?? 0;
  if (!_isPhone(phone) || type < 1 || type > 3) {
    throw const _MockBiz(400, 2, '参数错误');
  }
  return _jsonResponse(const {});
}

// 密码需 8~64 位且同时包含大小写字母与数字。
void _assertPasswordStrength(String password) {
  if (password.length < 8 || password.length > 64) {
    throw const _MockBiz(400, 2, '密码过长或过短');
  }
  var hasUpper = false;
  var hasLower = false;
  var hasDigit = false;
  for (final code in password.codeUnits) {
    final char = String.fromCharCode(code);
    if (char == char.toUpperCase() && char != char.toLowerCase()) {
      hasUpper = true;
    } else if (char == char.toLowerCase() && char != char.toUpperCase()) {
      hasLower = true;
    } else if (code >= 48 && code <= 57) {
      hasDigit = true;
    }
  }
  if (!(hasUpper && hasLower && hasDigit)) {
    throw const _MockBiz(400, 2, '密码强度过弱，至少需要包含大小写字母和数字');
  }
}

bool _isPhone(String phone) => RegExp(r'^1[3-9]\d{9}$').hasMatch(phone);

// 解析 Bearer 令牌：缺失为 anonymous，格式或载荷不对为 invalid，过期为 expired。
_Auth _parseAuth(Map<String, String> headers) {
  var authorization = '';
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'authorization') {
      authorization = entry.value.trim();
      break;
    }
  }
  if (authorization.isEmpty) return const _Auth('anonymous', 0);
  if (!authorization.startsWith('Bearer ')) return const _Auth('invalid', 0);
  final token = authorization.substring(7).trim();
  if (token.isEmpty) return const _Auth('invalid', 0);
  final payload = _decodeJwtPayload(token);
  if (payload == null) return const _Auth('invalid', 0);
  final exp = payload['exp'];
  if (exp is num &&
      exp.toInt() > 0 &&
      exp.toInt() < DateTime.now().millisecondsSinceEpoch ~/ 1000) {
    return const _Auth('expired', 0);
  }
  final userId = payload['userId'];
  if (userId is! num || userId.toInt() <= 0) return const _Auth('invalid', 0);
  return _Auth('authenticated', userId.toInt());
}

// 只解码载荷不验签（mock 令牌签名是固定占位串）。
Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final decoded = utf8.decode(
      base64Url.decode(base64Url.normalize(parts[1])),
    );
    final json = jsonDecode(decoded);
    return json is Map<String, dynamic> ? json : null;
  } catch (_) {
    return null;
  }
}

/// 不带过期时间的访问令牌，供 mock 入口与测试直接以指定用户登录。
String mockAccessTokenForUser(int userId) => _buildFakeJwt(userId);

/// 已过期的访问令牌，供测试覆盖 expired 鉴权状态与刷新流程。
String mockExpiredTokenForUser(int userId) => _buildFakeJwt(
  userId,
  exp: DateTime.now().millisecondsSinceEpoch ~/ 1000 - 10,
);

/// 与真实网关对齐的令牌对：access 短时效、refresh 7 天。
Map<String, String> mockTokenPairForUser(int userId) {
  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return {
    'token': _buildFakeJwt(userId, exp: nowSec + _mockAccessTtlSeconds),
    'refreshToken': _buildFakeJwt(userId, exp: nowSec + _mockRefreshTtlSeconds),
  };
}

/// 7 天有效的刷新令牌，供 mock 入口写入初始会话。
String mockRefreshTokenForUser(int userId) =>
    mockTokenPairForUser(userId)['refreshToken']!;

// 构造 `alg: none` 的三段式假 JWT，载荷含 userId、可选 exp 与唯一 jti。
String _buildFakeJwt(int userId, {int? exp}) {
  // 唯一 jti 模拟真实网关的一次性令牌：同秒内轮换也产出不同字符串。
  final nonce = ++_mockJwtNonce;
  final header = base64Url
      .encode(utf8.encode('{"alg":"none","typ":"JWT"}'))
      .replaceAll('=', '');
  final claims = exp == null
      ? '{"userId":$userId,"jti":"n$nonce"}'
      : '{"userId":$userId,"exp":$exp,"jti":"n$nonce"}';
  final payload = base64Url.encode(utf8.encode(claims)).replaceAll('=', '');
  return '$header.$payload.fake-sig';
}
