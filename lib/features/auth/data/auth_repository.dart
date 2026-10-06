import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart';
import '../../../sdk/data/gateway.dart';

/// 认证接口仓储：经生成 SDK 调用网关 `/api/v1/auth/*`，失败统一转为 `ApiException`。
/// 只负责请求，不写令牌；会话的建立与清理由 `AuthNotifier` 完成。
class AuthRepository {
  /// 用户名密码登录（`POST /api/v1/auth/login`，loginType 1）。
  Future<LoginResp> loginWithPassword(String username, String password) {
    return apiCall<LoginResp>(
      (ok, fail, eventually) => login(
        LoginReq(
          username: username,
          password: password,
          phone: '',
          verifyCode: '',
          loginType: 1,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 手机验证码登录（同一登录接口，loginType 2）。
  Future<LoginResp> loginWithVerifyCode(String phone, String code) {
    return apiCall<LoginResp>(
      (ok, fail, eventually) => login(
        LoginReq(
          username: '',
          password: '',
          phone: phone,
          verifyCode: code,
          loginType: 2,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 注册新账号（`POST /api/v1/auth/register`），响应携带新账号的令牌对。
  Future<RegisterResp> registerUser({
    required String username,
    required String password,
    required String phone,
    required String verifyCode,
  }) {
    return apiCall<RegisterResp>(
      (ok, fail, eventually) => register(
        RegisterReq(
          username: username,
          password: password,
          phone: phone,
          verifyCode: verifyCode,
        ),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 发送短信验证码（`POST /api/v1/auth/verify-code`）；[type] 取 `VerifyCodePurpose.wireType`。
  Future<SendVerifyCodeResp> sendCode(String phone, int type) {
    return apiCall<SendVerifyCodeResp>(
      (ok, fail, eventually) => sendVerifyCode(
        SendVerifyCodeReq(phone: phone, type: type),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
