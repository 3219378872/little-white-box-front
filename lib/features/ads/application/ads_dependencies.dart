import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../data/ads_repository.dart';

/// 广告主、广告与投放上报仓储；携带客户端身份用于曝光/点击归因。
final adsRepositoryProvider = Provider<AdsRepository>((ref) {
  return AdsRepository(identityStore: ref.read(clientIdentityStoreProvider));
});

/// 广告素材与资质文件选择器；测试注入假实现以避免调起系统对话框。
final adAssetPickerProvider = Provider<AdAssetPicker>(
  (ref) => const AdAssetPicker(),
);
