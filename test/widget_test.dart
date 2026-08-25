import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/app.dart';
import 'package:xiaobaihe_app/core/auth/session_tokens.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart' as mock_router;
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

final _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhf'
  'DwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// 把所有图片请求替换为 1x1 PNG，避免 smoke test 触碰真实网络。
class _StubImageOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _StubHttpClient();
}

class _StubHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _StubHttpRequest();

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        'smoke test does not support ${invocation.memberName}',
      );
}

class _StubHttpRequest implements HttpClientRequest {
  final _headers = _StubHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async => _StubHttpResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        'smoke test does not support ${invocation.memberName}',
      );
}

class _StubHttpResponse implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
        'smoke test does not support ${invocation.memberName}',
      );
}

class _StubHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('boots the real app shell against the in-repo mock gateway',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    HttpOverrides.global = _StubImageOverrides();
    addTearDown(() => HttpOverrides.global = null);
    addTearDown(() => setApiClient(http.Client()));
    addTearDown(removeTokens);

    setApiClient(MockHttpClient());
    await setTokens(buildStoredTokens(
      accessToken: mock_router.mockAccessTokenForUser(1),
      refreshToken: mock_router.mockRefreshTokenForUser(1),
    ));

    await tester.pumpWidget(const ProviderScope(child: XiaobaiheApp()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // 信息流渲染出 mock 语料的帖子标题。
    expect(find.text('探店｜藏在巷子里的宝藏面馆'), findsOneWidget);
  });
}
