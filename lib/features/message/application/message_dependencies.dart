import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/message_repository.dart';

/// 私信会话、线程与未读汇总共用的数据源；测试在此注入假实现。
final messageRepositoryProvider = Provider<MessageDataSource>((ref) {
  return const MessageRepository();
});
