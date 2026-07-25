import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production UI only uses Material in the app shell', () {
    const materialImport = 'package:flutter/material.dart';
    const materialImportAllowlist = {
      'lib/app.dart',
      'lib/core/theme/app_theme.dart',
    };
    final bannedWidgets = RegExp(
      r'\b(?:Scaffold|AppBar|SliverAppBar|SnackBar|ScaffoldMessenger|'
      r'TextField|InputDecoration|FilledButton|OutlinedButton|TextButton|'
      r'IconButton|SegmentedButton|ButtonSegment|Chip|CircleAvatar|Divider|'
      r'InkWell|RefreshIndicator|CircularProgressIndicator|TabBar|TabBarView|'
      r'TabController|AlertDialog|Shimmer)\b',
    );

    final violations = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path;
      final source = entity.readAsStringSync();
      if (source.contains(materialImport) &&
          !materialImportAllowlist.contains(path)) {
        violations.add('$path imports Material');
      }
      if (!materialImportAllowlist.contains(path) &&
          bannedWidgets.hasMatch(source)) {
        violations.add('$path contains a banned Material widget');
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}
