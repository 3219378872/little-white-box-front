import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class XiaobaiheApp extends ConsumerWidget {
  const XiaobaiheApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: '小白盒',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      supportedLocales: FLocalizations.supportedLocales,
      localizationsDelegates: const [...FLocalizations.localizationsDelegates],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => FTheme(
        data: Theme.brightnessOf(context) == Brightness.light
            ? AppTheme.foruiLight
            : AppTheme.foruiDark,
        child: FToaster(child: FTooltipGroup(child: child!)),
      ),
    );
  }
}
