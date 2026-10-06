import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/review/data/review_repository.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

import '../../helpers/gateway_fake.dart';

AdsRepository adsRepository() => AdsRepository(
  identityStore: ClientIdentityStore(generateId: (prefix) => '$prefix-1'),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => setApiClient(http.Client()));

  test('a missing advertiser is null rather than an error', () async {
    setApiClient(ScriptedGatewayClient.always({'found': false}));
    expect(await adsRepository().getMyAdvertiser(), isNull);
  });

  test('apply rejects a response without the advertiser', () async {
    setApiClient(ScriptedGatewayClient.always({'found': false}));
    await expectLater(
      adsRepository().applyAdvertiser(
        ApplyAdvertiserReq(
          name: 'Acme',
          markets: const ['US'],
          expectedRevision: 0,
          idempotencyKey: 'k',
        ),
      ),
      throwsA(isA<ApiException>()),
    );
  });

  test('hide sends the session id for anonymous hiding', () async {
    final client = ScriptedGatewayClient.always({'ok': true});
    setApiClient(client);

    await adsRepository().hideAd(7001);

    final request = client.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v2/ads/7001/hide');
    expect(jsonBodyOf(request), {'adId': 7001, 'sessionId': 'session-1'});
  });

  test('report sends the session id and a structured reason', () async {
    final client = ScriptedGatewayClient.always({'counted': true});
    setApiClient(client);

    expect(await adsRepository().reportAd(7001, 'scam'), isTrue);

    final request = client.requests.single;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v2/ads/7001/report');
    expect(jsonBodyOf(request), {
      'adId': 7001,
      'sessionId': 'session-1',
      'reason': 'scam',
    });
  });

  test('appeal posts the idempotency key and returns the ad', () async {
    final client = ScriptedGatewayClient.always({
      'ad': {'adId': 7003, 'reviewStatus': 'appealing', 'appealedRevision': 1},
    });
    setApiClient(client);

    final ad = await adsRepository().appealAd(7003, 'appeal-1');

    expect(ad.reviewStatus, 'appealing');
    expect(ad.appealedRevision, 1);
    final request = client.requests.single;
    expect(request.url.path, '/api/v2/ads/7003/appeal');
    expect(jsonBodyOf(request), {'adId': 7003, 'idempotencyKey': 'appeal-1'});
  });

  test('hide treats ok=false as a failure', () async {
    setApiClient(ScriptedGatewayClient.always({'ok': false}));
    await expectLater(adsRepository().hideAd(1), throwsA(isA<ApiException>()));
  });

  test('lists ads with cursor paging and reads private assets', () async {
    final client = ScriptedGatewayClient((request) async {
      if (request.url.path == '/api/v2/ads') {
        return jsonResponse(
          okEnvelope({'ads': <Object>[], 'nextCursor': 'n', 'hasMore': true}),
        );
      }
      return jsonResponse(
        okEnvelope({
          'mimeType': 'image/png',
          'contentBase64': base64Encode([1, 2, 3]),
        }),
      );
    });
    setApiClient(client);
    final repository = adsRepository();

    final page = await repository.listAds(cursor: 'c', pageSize: 5);
    final bytes = await repository.readAsset(9);

    expect(client.requests.first.url.queryParameters, {
      'cursor': 'c',
      'pageSize': '5',
    });
    expect(page.nextCursor, 'n');
    expect(bytes, [1, 2, 3]);
    expect(client.requests.last.url.path, '/api/v2/ads/assets/9');
  });

  test('uploads assets as multipart with an idempotency key', () async {
    final client = ScriptedGatewayClient.always({
      'assetId': 81,
      'kind': 'document',
      'sha256': 'x',
      'mimeType': 'application/pdf',
      'size': 3,
    });
    setApiClient(client);

    final asset = await adsRepository().uploadAsset(
      kind: AdAssetKind.document,
      file: XFile.fromData(
        Uint8List.fromList([1, 2, 3]),
        name: 'license.pdf',
        path: 'license.pdf',
      ),
      idempotencyKey: 'upload-1',
    );

    final request = client.requests.single as http.MultipartRequest;
    expect(request.url.path, '/api/v2/ads/assets/document');
    expect(request.fields, {'idempotencyKey': 'upload-1'});
    expect(request.files.single.contentType.mimeType, 'application/pdf');
    expect(asset.assetId, 81);
  });

  test('sniffs the asset type when the name and picker give none', () async {
    // 无扩展名、未声明 MIME 的 WebP 素材按文件头识别，而不是一律当作 JPEG。
    final client = ScriptedGatewayClient.always({
      'assetId': 82,
      'kind': 'creative',
      'sha256': 'x',
      'mimeType': 'image/webp',
      'size': 12,
    });
    setApiClient(client);

    await adsRepository().uploadAsset(
      kind: AdAssetKind.creative,
      file: XFile.fromData(
        Uint8List.fromList(utf8.encode('RIFF\x00\x00\x00\x00WEBP')),
        name: 'creative',
      ),
      idempotencyKey: 'upload-2',
    );

    final request = client.requests.single as http.MultipartRequest;
    expect(request.files.single.contentType.mimeType, 'image/webp');
  });

  test('oversized assets are rejected before upload', () async {
    final client = ScriptedGatewayClient.always(const {});
    setApiClient(client);
    await expectLater(
      adsRepository().uploadAsset(
        kind: AdAssetKind.creative,
        file: XFile.fromData(Uint8List(maxAdAssetBytes + 1), name: 'big.png'),
        idempotencyKey: 'k',
      ),
      throwsA(isA<ApiException>()),
    );
    expect(client.requests, isEmpty);
  });

  group('ReviewRepository', () {
    test('an empty queue claim returns null', () async {
      final client = ScriptedGatewayClient.always({'found': false});
      setApiClient(client);

      expect(await const ReviewRepository().claim(purpose: 'qa'), isNull);
      expect(jsonBodyOf(client.requests.single), {'purpose': 'qa'});
    });

    test('lease commands carry the generation', () async {
      final client = ScriptedGatewayClient.always({'ok': true});
      setApiClient(client);

      await const ReviewRepository().release(42, 3);

      expect(
        client.requests.single.url.path,
        '/api/v2/review/tasks/42/release',
      );
      expect(jsonBodyOf(client.requests.single), {
        'taskId': 42,
        'leaseGeneration': 3,
      });
    });

    test('evidence media is decoded from base64', () async {
      setApiClient(
        ScriptedGatewayClient.always({
          'mimeType': 'application/pdf',
          'contentBase64': base64Encode([9, 9]),
        }),
      );

      final media = await const ReviewRepository().media(42, 7);

      expect(media.bytes, [9, 9]);
      expect(media.isImage, isFalse);
    });
  });
}
