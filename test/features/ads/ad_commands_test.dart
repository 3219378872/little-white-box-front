import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xiaobaihe_app/core/analytics/client_identity_store.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/state/app_provider_scope.dart';
import 'package:xiaobaihe_app/features/ads/application/ad_commands.dart';
import 'package:xiaobaihe_app/features/ads/application/ads_dependencies.dart';
import 'package:xiaobaihe_app/features/ads/application/ads_providers.dart';
import 'package:xiaobaihe_app/features/ads/data/ads_repository.dart';
import 'package:xiaobaihe_app/features/ads/presentation/ad_labels.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

// 按脚本依次抛出给定错误（null 表示成功），记录每次写请求携带的幂等键。
class _ScriptedAdsRepository extends AdsRepository {
  final List<ApiException?> outcomes;
  final List<String> keys = [];

  _ScriptedAdsRepository(this.outcomes)
    : super(identityStore: ClientIdentityStore());

  Future<void> _next(String key) async {
    keys.add(key);
    final outcome = outcomes.removeAt(0);
    if (outcome != null) throw outcome;
  }

  @override
  Future<AdvertiserItem> applyAdvertiser(ApplyAdvertiserReq req) async {
    await _next(req.idempotencyKey);
    return AdvertiserItem.fromJson({'name': req.name});
  }

  @override
  Future<AdItem> appealAd(Object adId, String idempotencyKey) async {
    await _next(idempotencyKey);
    return AdItem.fromJson({'adId': adId});
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer containerWith(AdsRepository repository) {
    final container = createAppProviderContainer(
      overrides: [adsRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'advertiser retries reuse the key until input or verdict changes',
    () async {
      final repository = _ScriptedAdsRepository([
        const ApiException('offline'),
        const ApiException('version', code: 2007),
        null,
        null,
      ]);
      final container = containerWith(repository);
      final subscription = container.listen(
        advertiserCommandsProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final commands = subscription.read();

      Future<void> apply(String name) =>
          commands.apply(name: name, markets: {'US'}, current: null);

      // 网络失败 → 同键重试；业务错误码 → 作废；成功后同输入也换新键。
      await expectLater(apply('主体甲'), throwsA(isA<ApiException>()));
      await expectLater(apply('主体甲'), throwsA(isA<ApiException>()));
      await apply('主体甲');
      await apply('主体甲');

      expect(repository.keys[0], repository.keys[1]);
      expect(repository.keys[2], isNot(repository.keys[1]));
      expect(repository.keys[3], isNot(repository.keys[2]));
    },
  );

  test('advertiser validation fails before any request', () async {
    final repository = _ScriptedAdsRepository([]);
    final container = containerWith(repository);
    final commands = container.read(advertiserCommandsProvider);

    await expectLater(
      commands.apply(name: '甲', markets: {'US'}, current: null),
      throwsA(isA<AdFormInvalidException>()),
    );
    await expectLater(
      commands.apply(name: '主体甲', markets: {}, current: null),
      throwsA(isA<AdFormInvalidException>()),
    );
    expect(repository.keys, isEmpty);
  });

  test('appeal reuses the key only across network failures', () async {
    final repository = _ScriptedAdsRepository([
      const ApiException('offline'),
      null,
      null,
    ]);
    final container = containerWith(repository);
    final subscription = container.listen(
      adAppealCommandsProvider('7'),
      (_, _) {},
    );
    addTearDown(subscription.close);
    final commands = subscription.read();

    await expectLater(commands.appeal(), throwsA(isA<ApiException>()));
    await commands.appeal();
    await commands.appeal();

    expect(repository.keys[0], repository.keys[1]);
    expect(repository.keys[2], isNot(repository.keys[1]));
  });

  test('policy catalog falls back to local labels and lists', () {
    expect(resolveAdPolicyCatalog(null), same(fallbackAdPolicyCatalog));

    final remote = AdPolicyCatalog(
      policyVersion: 'v2',
      codes: [AdPolicyCodeItem(code: 'CONTENT.IP', title: '侵权', category: '')],
      markets: const [],
      industries: const ['GENERAL'],
      demo: false,
    );
    final resolved = resolveAdPolicyCatalog(remote);
    expect(resolved.markets, fallbackAdPolicyCatalog.markets);
    expect(resolved.industries, ['GENERAL']);
    expect(resolved.titleOf('CONTENT.IP'), '侵权');
    expect(resolved.titleOf('LANDING.URL'), '落地页地址不合规');
    expect(resolved.titleOf('X.Y'), 'X.Y');
  });
}
