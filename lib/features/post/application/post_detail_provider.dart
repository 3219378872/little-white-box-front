import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../sdk/data/gateway.dart';
import '../../auth/application/auth_notifier.dart';
import 'post_dependencies.dart';

/// 帖子详情；随会话身份重建，确保点赞/收藏态属于当前账号。
final postDetailProvider = FutureProvider.autoDispose
    .family<GetPostResp, String>((ref, postId) {
      ref.watch(authSessionIdentityProvider);
      return ref.read(postRepositoryProvider).getPostDetail(postId);
    });
