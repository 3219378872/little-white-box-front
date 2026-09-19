import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/post/presentation/post_editor_page.dart';
import 'package:xiaobaihe_app/features/post/presentation/widgets/image_picker_grid.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../../helpers/forui_test_builder.dart';
import '../../../helpers/gateway_fake.dart';

Map<String, dynamic> _post(int id) => {
  'id': id,
  'authorId': 7,
  'title': 'title-$id',
  'content': 'body-$id',
  'images': <String>[],
  'tags': ['tag-$id'],
  'revision': id,
  'status': 1,
};

Future<GoRouter> _pumpEditor(WidgetTester tester) async {
  final router = GoRouter(
    initialLocation: '/post/edit/9',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
        routes: [
          GoRoute(
            path: 'post/edit/:postId',
            builder: (_, state) =>
                PostEditorPage(postId: state.pathParameters['postId']),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    AppProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        builder: foruiTestBuilder,
      ),
    ),
  );
  await tester.pump();
  return router;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  testWidgets(
    'a late upload cannot submit the previous draft to the new post',
    (tester) async {
      final upload = Completer<http.Response>();
      final client = ScriptedGatewayClient((request) async {
        if (request.method == 'POST') return upload.future;
        return jsonResponse(
          okEnvelope(_post(int.parse(request.url.path.split('/').last))),
        );
      });
      setApiClient(client);
      final router = await _pumpEditor(tester);
      await tester.pumpAndSettle();
      final picker = tester.widget<ImagePickerGrid>(
        find.byType(ImagePickerGrid),
      );
      picker.onAdd(
        XFile.fromData(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
            'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
          ),
          name: 'pixel.png',
        ),
      );
      await tester.tap(find.text('发布'));
      await tester.pump();
      expect(client.requests.last.url.path, '/api/v1/media/image');
      router.go('/post/edit/10');
      await tester.pumpAndSettle();
      upload.complete(
        jsonResponse(
          okEnvelope({'mediaId': 51, 'url': 'https://media.test/51.png'}),
        ),
      );
      await tester.pumpAndSettle();
      expect(client.requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(find.text('title-10'), findsOneWidget);
      expect(
        tester
            .widget<ImagePickerGrid>(find.byType(ImagePickerGrid))
            .localImages,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'changing editor ID loads and submits the new post and revision',
    (tester) async {
      final client = ScriptedGatewayClient((request) async {
        if (request.method == 'GET') {
          return jsonResponse(
            okEnvelope(_post(int.parse(request.url.path.split('/').last))),
          );
        }
        return jsonResponse(okEnvelope({'revision': 11, 'status': 1}));
      });
      setApiClient(client);
      final router = await _pumpEditor(tester);
      await tester.pumpAndSettle();
      expect(find.text('title-9'), findsOneWidget);
      router.go('/post/edit/10');
      await tester.pumpAndSettle();
      expect(find.text('title-10'), findsOneWidget);
      expect(find.text('title-9'), findsNothing);
      expect(find.text('tag-9'), findsNothing);
      await tester.tap(find.text('发布'));
      await tester.pumpAndSettle();
      final request = client.requests.last;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/v2/post/10');
      expect(jsonBodyOf(request), containsPair('title', 'title-10'));
      expect(jsonBodyOf(request), containsPair('content', 'body-10'));
      expect(jsonBodyOf(request), containsPair('expectedRevision', 10));
      expect(jsonBodyOf(request)['tags'], ['tag-10']);
    },
  );

  for (final failure in [false, true]) {
    testWidgets(
      'old post load ${failure ? 'failure' : 'success'} cannot replace or close the new editor',
      (tester) async {
        final old = Completer<http.Response>();
        final next = Completer<http.Response>();
        final client = ScriptedGatewayClient(
          (request) =>
              request.url.path.endsWith('/9') ? old.future : next.future,
        );
        setApiClient(client);
        final router = await _pumpEditor(tester);
        router.go('/post/edit/10');
        await tester.pump();
        await tester.tap(find.text('发布'));
        await tester.pump();
        expect(client.requests.every((r) => r.method == 'GET'), isTrue);
        next.complete(jsonResponse(okEnvelope(_post(10))));
        await tester.pumpAndSettle();
        old.complete(
          failure
              ? jsonResponse({'code': 500, 'message': 'old failure'}, 500)
              : jsonResponse(okEnvelope(_post(9))),
        );
        await tester.pumpAndSettle();
        expect(find.text('title-10'), findsOneWidget);
        expect(find.text('title-9'), findsNothing);
        expect(find.textContaining('加载失败'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'old save ${failure ? 'failure' : 'success'} cannot close the new editor',
      (tester) async {
        final oldSave = Completer<http.Response>();
        final client = ScriptedGatewayClient((request) async {
          if (request.method == 'PUT') return oldSave.future;
          return jsonResponse(
            okEnvelope(_post(int.parse(request.url.path.split('/').last))),
          );
        });
        setApiClient(client);
        final router = await _pumpEditor(tester);
        await tester.pumpAndSettle();
        await tester.tap(find.text('发布'));
        await tester.pump();
        expect(client.requests.last.url.path, '/api/v2/post/9');
        router.go('/post/edit/10');
        await tester.pumpAndSettle();
        oldSave.complete(
          failure
              ? jsonResponse({'code': 500, 'message': 'old failure'}, 500)
              : jsonResponse(okEnvelope({'revision': 10, 'status': 1})),
        );
        await tester.pumpAndSettle();
        expect(find.text('title-10'), findsOneWidget);
        expect(find.textContaining('old failure'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
