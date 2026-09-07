import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_notifier.dart';
import '../data/assistant_repository.dart';

final assistantRepositoryProvider = Provider<AssistantDataSource>((ref) {
  return AssistantRepository();
});

final assistantUserKeyProvider = Provider<String>((ref) {
  return ref.watch(authenticatedSessionIdentityProvider) ?? '';
});
