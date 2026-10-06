import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/features/profile/application/edit_profile_controller.dart';
import 'package:xiaobaihe_app/features/profile/data/user_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

// 资料读取按脚本返回或失败，保存请求由测试控制完成时机。
class _ScriptedUserRepository extends UserRepository {
  final List<Object> loads = [];
  final List<UpdateProfileReq> saves = [];
  bool failLoad;
  Completer<void> saveResponse = Completer<void>();

  _ScriptedUserRepository({this.failLoad = false});

  @override
  Future<GetUserResp> getUserProfile(Object userId) async {
    loads.add(userId);
    if (failLoad) throw const ApiException('服务器错误');
    return GetUserResp.fromJson({
      'id': userId,
      'username': 'admin',
      'nickname': '旧昵称',
      'avatarUrl': 'https://cdn.example.com/a.png',
      'bio': '旧简介',
    });
  }

  @override
  Future<void> updateUserProfile(UpdateProfileReq req) {
    saves.add(req);
    return saveResponse.future;
  }
}

// 等待构造时发起的异步载入落定。
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('does not load until the user identity is known', () async {
    final repository = _ScriptedUserRepository();
    final controller = EditProfileController(repository: repository);
    addTearDown(controller.dispose);
    await _settle();

    expect(repository.loads, isEmpty);
    expect(controller.state.profile, isNull);
    expect(controller.state.canSave, isFalse);
  });

  test('loads the profile for the current user', () async {
    final repository = _ScriptedUserRepository();
    final controller = EditProfileController(repository: repository, userId: 7);
    addTearDown(controller.dispose);
    await _settle();

    expect(repository.loads, [7]);
    expect(controller.state.profile?.nickname, '旧昵称');
    expect(controller.state.profile?.bio, '旧简介');
    expect(controller.state.canSave, isTrue);
  });

  test('a failed load is retryable', () async {
    final repository = _ScriptedUserRepository(failLoad: true);
    final controller = EditProfileController(repository: repository, userId: 7);
    addTearDown(controller.dispose);
    await _settle();

    expect(controller.state.loadError, isA<ApiException>());
    expect(controller.state.canSave, isFalse);

    // 重试期间回到载入中，成功后清掉错误。
    repository.failLoad = false;
    final retry = controller.load();
    expect(controller.state.loadError, isNull);
    expect(controller.state.profile, isNull);
    await retry;
    expect(controller.state.profile?.nickname, '旧昵称');
  });

  test('saves trimmed text with the unchanged avatar', () async {
    final repository = _ScriptedUserRepository();
    final controller = EditProfileController(repository: repository, userId: 7);
    addTearDown(controller.dispose);
    await _settle();

    final save = controller.save(nickname: '  新昵称 ', bio: ' 新简介  ');
    expect(controller.state.isSaving, isTrue);
    expect(controller.state.canSave, isFalse);
    // 保存在途时重复点击不再发请求。
    await controller.save(nickname: '再次', bio: '');
    repository.saveResponse.complete();
    await save;

    expect(repository.saves, hasLength(1));
    expect(repository.saves.single.toJson(), {
      'nickname': '新昵称',
      'avatarUrl': 'https://cdn.example.com/a.png',
      'bio': '新简介',
    });
    expect(controller.state.isSaving, isFalse);
  });

  test('a failed save rethrows and releases the busy flag', () async {
    final repository = _ScriptedUserRepository();
    final controller = EditProfileController(repository: repository, userId: 7);
    addTearDown(controller.dispose);
    await _settle();

    final save = controller.save(nickname: '新昵称', bio: '');
    repository.saveResponse.completeError(const ApiException('服务器错误'));

    await expectLater(save, throwsA(isA<ApiException>()));
    expect(controller.state.isSaving, isFalse);
    expect(controller.state.canSave, isTrue);
  });
}
