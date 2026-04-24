import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/api/api_adapter.dart' as api;
import 'sdk/vars/kv.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  api.onAuthError = () async {
    await removeTokens();
  };
  runApp(const ProviderScope(child: XiaobaiheApp()));
}
