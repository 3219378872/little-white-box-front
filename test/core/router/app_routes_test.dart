import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/router/app_routes.dart';

// 锁定每个路由常量与 builder 的输出文本：URL 是对外契约，任何改动都应先在这里显式更新。
void main() {
  test('static route constants keep their exact URL text', () {
    expect(AppRoutes.feed, '/feed');
    expect(AppRoutes.search, '/search');
    expect(AppRoutes.messages, '/messages');
    expect(AppRoutes.profile, '/profile');
    expect(AppRoutes.login, '/auth/login');
    expect(AppRoutes.register, '/auth/register');
    expect(AppRoutes.postNew, '/post/new');
    expect(AppRoutes.profileEdit, '/profile/edit');
    expect(AppRoutes.assistant, '/messages/assistant');
    expect(AppRoutes.assistantMemory, '/messages/assistant/memory');
    expect(AppRoutes.ads, '/ads');
    expect(AppRoutes.adNew, '/ads/new');
    expect(AppRoutes.advertiser, '/ads/advertiser');
    expect(AppRoutes.review, '/review');
    expect(AppRoutes.legacyAssistant, '/assistant');
    expect(AppRoutes.legacyAssistantMemory, '/assistant/memory');
  });

  test('route table patterns keep their exact path and parameter names', () {
    expect(AppRoutes.messageThreadPattern, '/messages/:conversationId');
    expect(AppRoutes.postEditPattern, '/post/edit/:postId');
    expect(AppRoutes.postDetailPattern, '/post/:postId');
    expect(AppRoutes.userProfilePattern, '/user/:userId');
    expect(AppRoutes.adDetailPattern, '/ads/:adId');
    expect(AppRoutes.adEditPattern, '/ads/:adId/edit');
    expect(AppRoutes.reviewTaskPattern, '/review/tasks/:taskId');
  });

  test('id builders emit canonical decimal ids for int and string input', () {
    const bigId = '1234567890123456789';
    expect(AppRoutes.postDetail(42), '/post/42');
    expect(AppRoutes.postDetail(bigId), '/post/$bigId');
    expect(AppRoutes.postEdit(42), '/post/edit/42');
    expect(AppRoutes.userProfile(7), '/user/7');
    expect(AppRoutes.userProfile(bigId), '/user/$bigId');
    expect(AppRoutes.adDetail(9), '/ads/9');
    expect(AppRoutes.adEdit(9), '/ads/9/edit');
    expect(AppRoutes.adEdit(bigId), '/ads/$bigId/edit');
    expect(AppRoutes.reviewTask(3), '/review/tasks/3');
  });

  test('message thread builder encodes target user as query parameters', () {
    expect(
      AppRoutes.messageThread(5, targetUserId: 11, targetUserName: 'Alice'),
      '/messages/5?targetUserId=11&targetUserName=Alice',
    );
    expect(
      AppRoutes.messageThread(
        '1234567890123456789',
        targetUserId: '9876543210987654321',
        targetUserName: '小 白&盒',
      ),
      '/messages/1234567890123456789'
      '?targetUserId=9876543210987654321'
      '&targetUserName=%E5%B0%8F+%E7%99%BD%26%E7%9B%92',
    );
    expect(
      AppRoutes.messageThread(5, targetUserId: 11, targetUserName: ''),
      '/messages/5?targetUserId=11&targetUserName',
    );
  });
}
