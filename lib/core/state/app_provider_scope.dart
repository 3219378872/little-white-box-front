import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

/// Riverpod 3 retries failing providers by default. Keep explicit failure
/// states instead of silent retries (FQ-006).
Duration? disableProviderRetry(int retryCount, Object error) => null;

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

ProviderContainer createAppProviderContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(retry: disableProviderRetry, overrides: overrides);
}
