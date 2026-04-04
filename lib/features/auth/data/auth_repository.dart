import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart';
import '../../../sdk/data/gateway.dart';

class AuthRepository {
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
