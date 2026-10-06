import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/ads/application/ads_dependencies.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ad_detail_page.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ad_editor_page.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ads_page.dart';
import 'package:xiaobaihe_app/features/ads/presentation/advertiser_page.dart';
import 'package:xiaobaihe_app/mock/mock_http.dart';
import 'package:xiaobaihe_app/mock/mock_router.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';
import 'package:xiaobaihe_app/sdk/data/tokens.dart';
import 'package:xiaobaihe_app/sdk/vars/kv.dart';

import '../../helpers/forui_test_builder.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    resetMockState();
    setApiClient(MockHttpClient());
  });

  Future<void> signIn(int userId) => setTokens(
    Tokens(
      accessToken: mockAccessTokenForUser(userId),
      accessExpire: 0,
      refreshToken: '',
      refreshExpire: 0,
      refreshAfter: 0,
    ),
  );

  Future<GoRouter> pump(
    WidgetTester tester,
    String location, {
    ThemeMode themeMode = ThemeMode.light,
    bool fakePicker = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(path: '/ads', builder: (_, _) => const AdsPage()),
        GoRoute(path: '/ads/new', builder: (_, _) => const AdEditorPage()),
        GoRoute(
          path: '/ads/advertiser',
          builder: (_, _) => const AdvertiserPage(),
        ),
        GoRoute(
          path: '/ads/:adId',
          builder: (_, state) =>
              AdDetailPage(adId: state.pathParameters['adId']!),
        ),
        GoRoute(
          path: '/ads/:adId/edit',
          builder: (_, state) =>
              AdEditorPage(adId: state.pathParameters['adId']),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      AppProviderScope(
        overrides: [
          if (fakePicker)
            adAssetPickerProvider.overrideWithValue(const _FakePicker()),
        ],
        child: MaterialApp.router(
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: themeMode,
          routerConfig: router,
          builder: foruiTestBuilder,
        ),
      ),
    );
    await settle(tester);
    return router;
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    await tester.enterText(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
      text,
    );
    await tester.pump();
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('lists own ads with textual statuses (${mode.name})', (
      tester,
    ) async {
      await signIn(1);
      await pump(tester, '/ads', themeMode: mode);

      expect(find.text('小白盒周边店'), findsOneWidget);
      expect(find.text('社区限定桌搭套装第二波'), findsOneWidget);
      expect(find.text('审核：未通过'), findsNWidgets(2));
      expect(find.text('投放：投放中'), findsOneWidget);
      expect(find.text('投放：已下线'), findsOneWidget);
      expect(find.byKey(const Key('ads-new')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('non advertisers are guided to apply', (tester) async {
    await signIn(2);
    await pump(tester, '/ads');

    expect(find.text('还不是广告主'), findsOneWidget);
    expect(find.byKey(const Key('ads-new')), findsNothing);

    await tester.tap(find.byKey(const Key('ads-apply')));
    await settle(tester);
    expect(find.byType(AdvertiserPage), findsOneWidget);

    await enter(tester, 'advertiser-name', '新店铺');
    await tester.tap(find.byKey(const Key('advertiser-market-ID')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('advertiser-submit')));
    await settle(tester);

    expect(find.text('审核：审核中'), findsOneWidget);
    expect(find.text('提交行业资质'), findsOneWidget);
  });

  testWidgets('rejected ads show localized policy reasons', (tester) async {
    await signIn(1);
    await pump(tester, '/ads/7003');

    expect(find.byKey(const Key('ad-policy-reasons')), findsOneWidget);
    expect(
      find.textContaining('涉及时间、地域或品牌的绝对化用语（MISLEADING.ABSOLUTE）'),
      findsOneWidget,
    );
  });

  // FX-110 / ADS-014：被下线的版本显示下线原因与申诉入口；确认后进入申诉复审，不能再次申诉。
  testWidgets('an offline ad can be appealed once after confirming', (
    tester,
  ) async {
    await signIn(1);
    await pump(tester, '/ads/7004');

    expect(find.text('下线原因'), findsOneWidget);
    expect(find.text('用户举报经复审成立'), findsOneWidget);
    expect(find.text('对下线的 r1 申诉'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ad-appeal')));
    await settle(tester);
    expect(find.text('发起申诉'), findsOneWidget);
    await tester.tap(find.byKey(const Key('app-confirm-cancel')));
    await settle(tester);
    expect(find.byKey(const Key('ad-appealing')), findsNothing);

    await tester.tap(find.byKey(const Key('ad-appeal')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('app-confirm-ok')));
    await settle(tester);

    expect(find.byKey(const Key('ad-appealing')), findsOneWidget);
    expect(find.text('r1 申诉复审中'), findsOneWidget);
    expect(find.byKey(const Key('ad-appeal')), findsNothing);
    expect(find.text('审核：申诉中'), findsOneWidget);
  });

  testWidgets('an appeal already used elsewhere is explained and refreshed', (
    tester,
  ) async {
    await signIn(1);
    await pump(tester, '/ads/7003');
    expect(find.text('对未通过的 r1 申诉'), findsOneWidget);
    final used = dispatchResponse(
      'POST',
      '/api/v2/ads/7003/appeal',
      '{}',
      headers: {'Authorization': 'Bearer ${mockAccessTokenForUser(1)}'},
    );
    expect(used.statusCode, 200);

    await tester.tap(find.byKey(const Key('ad-appeal')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('app-confirm-ok')));
    await settle(tester);

    expect(find.text('当前版本不可申诉（每个版本只能申诉一次）'), findsOneWidget);
    expect(find.byKey(const Key('ad-appeal')), findsNothing);
    expect(find.byKey(const Key('ad-appealing')), findsOneWidget);
  });

  testWidgets('pending edits show the diff and the serving notice', (
    tester,
  ) async {
    await signIn(1);
    await pump(tester, '/ads/7001');

    expect(find.byKey(const Key('ad-diff')), findsOneWidget);
    expect(find.text('最新：社区限定桌搭套装第二波'), findsOneWidget);
    expect(find.text('审核期间继续投放上一过审版本'), findsOneWidget);
  });

  testWidgets('a revision conflict keeps the edited input', (tester) async {
    await signIn(1);
    await pump(tester, '/ads/7001/edit');
    expect(find.byKey(const Key('ad-editor-serving-notice')), findsOneWidget);

    final bump = dispatchResponse(
      'PUT',
      '/api/v2/ads/7001',
      jsonEncode({
        'adId': 7001,
        'expectedRevision': 2,
        'title': 'Elsewhere',
        'body': 'B',
        'cta': 'Go',
        'landingUrl': 'https://shop.example.com/desk',
        'market': 'US',
        'industry': 'GENERAL',
        'idempotencyKey': 'other-device',
      }),
      headers: {'Authorization': 'Bearer ${mockAccessTokenForUser(1)}'},
    );
    expect(bump.statusCode, 200);

    await enter(tester, 'ad-title', '我的新标题');
    await tester.tap(find.byKey(const Key('ad-submit')));
    await settle(tester);

    expect(find.text('广告已在别处更新，已保留你的输入，请刷新后再提交'), findsOneWidget);
    expect(find.text('我的新标题'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('creating an ad submits it for review and opens details', (
    tester,
  ) async {
    await signIn(1);
    final router = await pump(tester, '/ads/new');

    await enter(tester, 'ad-title', '新广告');
    await enter(tester, 'ad-body', '正文');
    await enter(tester, 'ad-cta', '了解更多');
    await enter(tester, 'ad-landing', 'https://new.example.com/a');
    await tester.tap(find.byKey(const Key('ad-submit')));
    await settle(tester);

    expect(router.routeInformationProvider.value.uri.path, '/ads/7100');
    expect(find.text('审核：审核中'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('client validation blocks non https landing pages', (
    tester,
  ) async {
    await signIn(1);
    final router = await pump(tester, '/ads/new');

    await enter(tester, 'ad-title', '新广告');
    await enter(tester, 'ad-body', '正文');
    await enter(tester, 'ad-cta', '了解更多');
    await enter(tester, 'ad-landing', 'http://new.example.com/a');
    await tester.tap(find.byKey(const Key('ad-submit')));
    await settle(tester);

    expect(find.text('落地页须为 https 地址'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/ads/new');
    await settle(tester, frames: 60);
  });

  testWidgets('uploads a document and submits a qualification', (tester) async {
    await signIn(1);
    await pump(tester, '/ads/advertiser', fakePicker: true);

    await tester.tap(find.byKey(const Key('qualification-industry-FINANCIAL')));
    await tester.tap(find.byKey(const Key('qualification-upload')));
    await settle(tester);
    expect(find.text('license.pdf'), findsOneWidget);
    await enter(tester, 'qualification-valid-until', '2099-12-31');
    await tester.tap(find.byKey(const Key('qualification-submit')));
    await settle(tester);

    expect(find.text('资质已提交，将与主体一起审核'), findsOneWidget);
    expect(find.text('美国（英语） · 金融服务'), findsOneWidget);
    // The form resets so a second tap cannot file the same document again.
    expect(find.text('license.pdf'), findsNothing);
    expect(find.text('JPG、PNG、WebP 或 PDF，不超过 2 MiB'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('a qualification needs a document and a future date', (
    tester,
  ) async {
    await signIn(1);
    await pump(tester, '/ads/advertiser', fakePicker: true);

    await tester.tap(find.byKey(const Key('qualification-submit')));
    await settle(tester);
    expect(find.text('请先上传资质证件'), findsOneWidget);
    await settle(tester, frames: 60);

    await tester.tap(find.byKey(const Key('qualification-upload')));
    await settle(tester);
    await enter(tester, 'qualification-valid-until', '2000-01-01');
    await tester.tap(find.byKey(const Key('qualification-submit')));
    await settle(tester);
    expect(find.text('有效期须为今天之后的日期，格式 YYYY-MM-DD'), findsOneWidget);
    await settle(tester, frames: 60);
  });

  testWidgets('creative images upload privately and can be removed', (
    tester,
  ) async {
    await signIn(1);
    await pump(tester, '/ads/new', fakePicker: true);

    await tester.tap(find.byKey(const Key('ad-add-creative')));
    await settle(tester);
    expect(find.text('创意图片（1/3）'), findsOneWidget);
    expect(find.bySemanticsLabel('创意图片 8100'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('移除图片 8100'));
    await settle(tester);
    expect(find.text('创意图片（0/3）'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FakePicker extends AdAssetPicker {
  const _FakePicker();

  @override
  Future<XFile?> pick(AdAssetKind kind) async => XFile.fromData(
    Uint8List.fromList([1, 2, 3]),
    name: kind == AdAssetKind.document ? 'license.pdf' : 'a.png',
    path: kind == AdAssetKind.document ? 'license.pdf' : 'a.png',
  );
}
