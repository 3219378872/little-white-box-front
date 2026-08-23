import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/router/public_routes.dart';

void main() {
  group('isPublicRoute', () {
    test('白名单页面匿名可访问', () {
      for (final route in publicRoutes) {
        expect(isPublicRoute(route), isTrue, reason: route);
      }
    });

    test('帖子详情匿名可访问', () {
      expect(isPublicRoute('/post/12345'), isTrue);
      expect(isPublicRoute('/post/9007199254740993'), isTrue);
    });

    test('发帖编辑器必须登录', () {
      expect(isPublicRoute('/post/new'), isFalse);
    });

    test('帖子编辑页必须登录', () {
      expect(isPublicRoute('/post/edit/12345'), isFalse);
    });

    test('用户主页匿名可访问', () {
      expect(isPublicRoute('/user/42'), isTrue);
    });

    test('受保护页面不公开', () {
      expect(isPublicRoute('/messages'), isFalse);
      expect(isPublicRoute('/assistant'), isFalse);
      expect(isPublicRoute('/profile'), isFalse);
      expect(isPublicRoute('/profile/edit'), isFalse);
    });
  });
}
