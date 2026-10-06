import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Riverpod 3 retries failing providers by default. Keep explicit failure
/// states instead of silent retries (FQ-006).
Duration? disableProviderRetry(int retryCount, Object error) => null;

/// 应用与 Widget 测试统一使用的 [ProviderScope]，固定关闭自动重试，测试通过 [overrides] 注入替身。
class AppProviderScope extends StatelessWidget {
  const AppProviderScope({
    super.key,
    this.overrides = const [],
    required this.child,
  });

  final List<Override> overrides;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      retry: disableProviderRetry,
      overrides: overrides,
      child: child,
    );
  }
}

/// 与 [AppProviderScope] 配置一致的 [ProviderContainer]，供无 Widget 树的测试使用。
ProviderContainer createAppProviderContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(retry: disableProviderRetry, overrides: overrides);
}
