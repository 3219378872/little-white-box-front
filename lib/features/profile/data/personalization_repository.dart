import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

class PersonalizationRepository {
  Future<GetPersonalizationPreferenceResp> getPreference() {
    return apiCall<GetPersonalizationPreferenceResp>(
      (ok, fail, eventually) => gw.getPersonalizationPreference(
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

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
