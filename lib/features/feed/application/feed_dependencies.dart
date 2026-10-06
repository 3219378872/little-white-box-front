import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/analytics/client_identity_store.dart';
import '../data/feed_repository.dart';

/// 推荐/关注信息流数据源；携带客户端身份以便推荐请求按设备去重。
final feedRepositoryProvider = Provider<FeedPageRepository>((ref) {
  return FeedRepository(identityStore: ref.read(clientIdentityStoreProvider));
});
