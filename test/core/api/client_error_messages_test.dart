import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/auth/data/auth_repository.dart';
import 'package:xiaobaihe_app/features/comment/data/comment_repository.dart';
import 'package:xiaobaihe_app/features/media/data/media_repository.dart';
import 'package:xiaobaihe_app/features/post/data/post_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

import '../../helpers/gateway_fake.dart';

// 断言异常是只带中文用户文案的 ApiException：英文诊断不能出现在 message 里。
Matcher _userMessage(String message) => isA<ApiException>()
    .having((error) => error.message, 'message', message)
    .having((error) => error.code, 'code', isNull);

// 让传输层直接抛出给定异常，模拟断网、跨域拦截等客户端失败。
void _failTransport(Object error) {
  setApiClient(ScriptedGatewayClient((_) async => throw error));
}

// 让传输层返回非网关信封的 HTTP 响应，模拟代理错误页或空响应体。
void _respond(String body, int statusCode) {
  setApiClient(
    ScriptedGatewayClient((_) async => http.Response(body, statusCode)),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  group('SDK apiCall boundary', () {
    test('network failures surface a Chinese network message', () async {
      _failTransport(http.ClientException('XMLHttpRequest error.'));
      await expectLater(
        AuthRepository().sendCode('13800000002', 2),
        throwsA(_userMessage('网络连接失败，请检查网络后重试')),
      );
    });

    test('SDK decode errors surface as unrecognized data', () async {
      // list 不是数组时生成 SDK 的 fromJson 抛 TypeError，被 SDK 以英文 toString 转交。
      setApiClient(ScriptedGatewayClient.always({'list': 'oops'}));
      await expectLater(
        CommentRepository().fetchComments(
          postId: 1,
          page: 1,
          pageSize: 20,
          sortBy: 1,
        ),
        throwsA(_userMessage('服务返回了无法识别的数据')),
      );
    });

    test('a bare HTTP status becomes a Chinese retry message', () async {
      _respond('', 502);
      await expectLater(
        AuthRepository().sendCode('13800000002', 2),
        throwsA(_userMessage('请求失败，请稍后重试（HTTP 502）')),
      );
    });

    test('a proxy error page is not shown verbatim', () async {
      _respond('<html><body>502 Bad Gateway</body></html>', 502);
      await expectLater(
        AuthRepository().sendCode('13800000002', 2),
        throwsA(_userMessage('请求失败，请稍后重试')),
      );
    });

    test('gateway business messages pass through unchanged', () async {
      setApiClient(
        ScriptedGatewayClient(
          (_) async => jsonResponse({'code': 1003, 'message': '密码错误'}, 400),
        ),
      );
      await expectLater(
        AuthRepository().sendCode('13800000002', 2),
        throwsA(
          isA<ApiException>()
              .having((error) => error.message, 'message', '密码错误')
              .having((error) => error.code, 'code', 1003),
        ),
      );
    });
  });

  group('multipart upload boundary', () {
    AdsRepository ads() => AdsRepository(
      identityStore: ClientIdentityStore(generateId: (prefix) => '$prefix-1'),
    );

    Future<void> uploadPostImage() =>
        PostRepository().uploadImageMultipart(bytes: [0], filename: 'a.png');

    Future<void> uploadAdAsset() => ads().uploadAsset(
      kind: AdAssetKind.creative,
      file: XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.png'),
      idempotencyKey: 'k',
    );

    Future<void> uploadMedia() => MediaRepository().upload(
      XFile.fromData(Uint8List.fromList([1, 2, 3]), name: 'a.png'),
      MediaKind.image,
      'k',
      isCurrent: () => true,
    );

    test('incomplete upload responses keep their Chinese reason', () async {
      setApiClient(ScriptedGatewayClient.always({'mediaId': 1}));
      await expectLater(uploadPostImage(), throwsA(_userMessage('上传响应缺少图片地址')));
      await expectLater(uploadAdAsset(), throwsA(_userMessage('上传响应缺少素材标识')));
      await expectLater(
        uploadMedia(),
        throwsA(_userMessage('上传响应缺少有效媒体标识或地址')),
      );
    });

    test('mistyped upload responses surface as unrecognized data', () async {
      setApiClient(ScriptedGatewayClient.always({'mediaId': 1, 'url': 7}));
      await expectLater(
        uploadPostImage(),
        throwsA(_userMessage('服务返回了无法识别的数据')),
      );
    });

    test('network failures surface a Chinese network message', () async {
      _failTransport(http.ClientException('Connection refused'));
      await expectLater(
        uploadPostImage(),
        throwsA(_userMessage('网络连接失败，请检查网络后重试')),
      );
    });

    test('a bare HTTP status becomes a Chinese retry message', () async {
      _respond('', 502);
      await expectLater(
        uploadPostImage(),
        throwsA(_userMessage('请求失败，请稍后重试（HTTP 502）')),
      );
    });
  });
}
