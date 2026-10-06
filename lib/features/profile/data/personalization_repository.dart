import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 个性化推荐偏好的 Gateway 封装（`/api/v2/me/personalization`），失败经 [apiCall] 转为 `ApiException`。
class PersonalizationRepository {
  /// 读取当前账号的个性化推荐开关（GET）。
  Future<GetPersonalizationPreferenceResp> getPreference() {
    return apiCall<GetPersonalizationPreferenceResp>(
      (ok, fail, eventually) => gw.getPersonalizationPreference(
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 写入个性化推荐开关（PUT）。
  Future<void> setPreference({required bool enabled}) {
    return apiCall<SetPersonalizationPreferenceResp>(
      (ok, fail, eventually) => gw.setPersonalizationPreference(
        SetPersonalizationPreferenceReq(enabled: enabled),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }
}
