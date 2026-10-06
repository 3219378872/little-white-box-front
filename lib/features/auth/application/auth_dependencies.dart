import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

/// 登录、注册与验证码请求的仓储；会话状态本身由 authNotifierProvider 持有。
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});
