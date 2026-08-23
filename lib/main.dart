import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/api/api_adapter.dart' as api;
import 'core/error/global_error_handlers.dart';
import 'sdk/vars/kv.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = handleFlutterError;
    PlatformDispatcher.instance.onError = handlePlatformError;
    api.onAuthError = () async {
      await removeTokens();
    };
    runApp(const ProviderScope(child: XiaobaiheApp()));
  }, handleZoneError);
}
