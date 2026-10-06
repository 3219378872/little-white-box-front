import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/error_codes.dart';

void main() {
  group('ErrorCodes', () {
    test('认证相关错误码值正确', () {
      expect(ErrorCodes.tokenExpired, 1004);
      expect(ErrorCodes.tokenInvalid, 1005);
      expect(ErrorCodes.loginRequired, 1006);
    });

    test('用户相关错误码值正确', () {
      expect(ErrorCodes.userNotFound, 1001);
      expect(ErrorCodes.userAlreadyExist, 1002);
      expect(ErrorCodes.passwordError, 1003);
    });

    test('内容相关错误码值正确', () {
      expect(ErrorCodes.contentNotFound, 2001);
      expect(ErrorCodes.contentForbidden, 2002);
      expect(ErrorCodes.contentEmpty, 2004);
      expect(ErrorCodes.postAlreadyDeleted, 2006);
    });

    test('交互相关错误码值正确', () {
      expect(ErrorCodes.favoritesPrivate, 3007);
    });

    test('Agent 相关错误码值正确', () {
      // 后端 pkg/errx/codes.go AgentNotAuthorized。
      expect(ErrorCodes.agentNotAuthorized, 6001);
    });

    test('isAuthError 辅助判断', () {
      expect(ErrorCodes.isAuthError(1004), isTrue);
      expect(ErrorCodes.isAuthError(1005), isTrue);
      expect(ErrorCodes.isAuthError(1006), isTrue);
      expect(ErrorCodes.isAuthError(1001), isFalse);
      expect(ErrorCodes.isAuthError(null), isFalse);
    });
  });
}
