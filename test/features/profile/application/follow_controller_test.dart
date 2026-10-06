import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/features/profile/application/follow_controller.dart';
import 'package:xiaobaihe_app/features/profile/application/personalization_controller.dart';
import 'package:xiaobaihe_app/features/profile/data/personalization_repository.dart';
import 'package:xiaobaihe_app/features/profile/data/user_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

// 记录关注请求并由测试控制完成时机，用于观察乐观态与回滚。
class _ScriptedUserRepository extends UserRepository {
  final List<String> calls = [];
  Completer<void> response = Completer<void>();

  @override
  Future<void> followUser(Object userId) {
    calls.add('follow:$userId');
    return response.future;
  }

  @override
  Future<void> unfollowUser(Object userId) {
    calls.add('unfollow:$userId');
    return response.future;
  }
}

// 偏好读写都由测试决定结果。
class _ScriptedPersonalizationRepository extends PersonalizationRepository {
  final bool initial;
  final bool failWrites;
  final List<bool> writes = [];

  _ScriptedPersonalizationRepository({
    this.initial = true,
    this.failWrites = false,
  });

  @override
  Future<GetPersonalizationPreferenceResp> getPreference() async {
    return GetPersonalizationPreferenceResp(enabled: initial, optedOutAt: 0);
  }

  @override
  Future<void> setPreference({required bool enabled}) async {
    writes.add(enabled);
    if (failWrites) throw Exception('offline');
  }
}

void main() {
  group('FollowController', () {
    test('flips optimistically and keeps the confirmed result', () async {
      final repo = _ScriptedUserRepository();
      final controller = FollowController(repository: repo, userId: '2');

      final pending = controller.toggle(false);
      expect(controller.state.following, isTrue);
      expect(controller.state.isBusy, isTrue);

      repo.response.complete();
      await pending;
      expect(repo.calls, ['follow:2']);
      expect(controller.state.following, isTrue);
      expect(controller.state.isBusy, isFalse);
      expect(controller.state.resolve(false), isTrue);
    });

    test('ignores taps while a request is in flight', () async {
      final repo = _ScriptedUserRepository();
      final controller = FollowController(repository: repo, userId: '2');

      final pending = controller.toggle(false);
      await controller.toggle(true);
      expect(repo.calls, ['follow:2']);

      repo.response.complete();
      await pending;
    });

    test('rolls back to the server value and rethrows on failure', () async {
      final repo = _ScriptedUserRepository();
      final controller = FollowController(repository: repo, userId: '2');

      final pending = controller.toggle(true);
      expect(controller.state.following, isFalse);
      repo.response.completeError(Exception('offline'));

      await expectLater(pending, throwsException);
      expect(repo.calls, ['unfollow:2']);
      expect(controller.state.following, isNull);
      expect(controller.state.resolve(true), isTrue);
      expect(controller.state.isBusy, isFalse);
    });
  });

  group('PersonalizationController', () {
    test('loads the stored preference', () async {
      final controller = PersonalizationController(
        _ScriptedPersonalizationRepository(initial: false),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.enabled, isFalse);
    });

    test('restores the previous value when the write fails', () async {
      final repo = _ScriptedPersonalizationRepository(failWrites: true);
      final controller = PersonalizationController(repo);
      await Future<void>.delayed(Duration.zero);

      await expectLater(controller.setEnabled(false), throwsException);
      expect(repo.writes, [false]);
      expect(controller.state.enabled, isTrue);
      expect(controller.state.isBusy, isFalse);
    });
  });
}
