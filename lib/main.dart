import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/error/global_error_handlers.dart';
import 'core/state/app_provider_scope.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = handlePlatformError;
    runApp(const AppProviderScope(child: XiaobaiheApp()));
  }, handleZoneError);
}
