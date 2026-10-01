import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/api/api_exceptions.dart';
import 'package:xiaobaihe_app/core/api/error_codes.dart';
import 'package:xiaobaihe_app/features/review/application/review_task_controller.dart';
import 'package:xiaobaihe_app/features/review/data/review_repository.dart';
import 'package:xiaobaihe_app/sdk/data/gateway.dart';

ReviewTaskItem task({
  String status = 'claimed',
  int generation = 3,
  int leaseUntilMs = 1000,
}) => ReviewTaskItem.fromJson({
  'taskId': 42,
  'bizType': 'ad_creative',
  'objectId': 7,
  'objectRevision': 2,
  'purpose': 'initial',
  'status': status,
  'market': 'US',
  'language': 'en',
  'leaseGeneration': generation,
  'leaseUntilMs': leaseUntilMs,
  'snapshotJson': '{}',
  'stages': <Object>[],
});

void main() {
  Future<(ReviewTaskController, _FakeReviewRepository, List<int>)> controller({
    ReviewTaskItem? initial,
  }) async {
    final repository = _FakeReviewRepository(initial ?? task());
    final forbidden = <int>[];
    final controller = ReviewTaskController(
      repository: repository,
      taskId: '42',
      onForbidden: () => forbidden.add(1),
      loadImmediately: false,
    );
    await controller.load();
    return (controller, repository, forbidden);
  }

  test('loads a claimed task as editable', () async {
    final (c, _, _) = await controller();
    expect(c.state.editable, isTrue);
    expect(c.state.task!.leaseGeneration, 3);
  });

  test('loads decided and superseded tasks as closed', () async {
    final (decided, _, _) = await controller(initial: task(status: 'decided'));
    expect(decided.state.closure, ReviewTaskClosure.decided);
    expect(decided.state.editable, isFalse);
    final (superseded, _, _) = await controller(
      initial: task(status: 'superseded'),
    );
    expect(superseded.state.closure, ReviewTaskClosure.superseded);
  });

  test('renew sends the current lease generation and keeps the task', () async {
    final (c, repository, _) = await controller();
    repository.renewed = task(leaseUntilMs: 9000);

    expect(await c.renew(), isTrue);

    expect(repository.leaseCalls, ['renew:3']);
    expect(c.state.task!.leaseUntilMs, 9000);
  });

  test('release closes the task without a retry', () async {
    final (c, repository, _) = await controller();

    expect(await c.release(), isTrue);
    expect(repository.leaseCalls, ['release:3']);
    expect(c.state.closure, ReviewTaskClosure.released);
    expect(c.state.editable, isFalse);
  });

  test('reject requires at least one policy code', () async {
    final (c, repository, _) = await controller();

    expect(await c.submit(verdict: 'reject', policyCodes: const []), isFalse);

    expect(repository.decisions, isEmpty);
    expect(c.state.error, contains('政策码'));
  });

  test('network retries reuse the key, business errors rotate it', () async {
    final (c, repository, _) = await controller();
    repository.decideErrors.addAll([
      const ApiException('请求超时'),
      const ApiException('参数错误', code: ErrorCodes.paramError),
    ]);

    await c.submit(verdict: 'reject', policyCodes: const ['B', 'A']);
    await c.submit(verdict: 'reject', policyCodes: const ['A', 'B']);
    await c.submit(verdict: 'reject', policyCodes: const ['A', 'B']);

    expect(repository.decisions, hasLength(3));
    expect(
      repository.decisions[0].idempotencyKey,
      repository.decisions[1].idempotencyKey,
    );
    expect(
      repository.decisions[2].idempotencyKey,
      isNot(repository.decisions[1].idempotencyKey),
    );
    expect(repository.decisions[2].policyCodes, ['A', 'B']);
    expect(repository.decisions[2].leaseGeneration, 3);
    expect(c.state.decision!.verdict, 'reject');
    expect(c.state.editable, isFalse);
  });

  test('approve never sends policy codes or seed nominations', () async {
    final (c, repository, _) = await controller();

    await c.submit(
      verdict: 'approve',
      policyCodes: const ['A'],
      nominateSeed: true,
    );

    expect(repository.decisions.single.policyCodes, isEmpty);
    expect(repository.decisions.single.nominateSeed, isFalse);
  });

  for (final (code, closure) in [
    (ErrorCodes.reviewLeaseLost, ReviewTaskClosure.leaseLost),
    (ErrorCodes.reviewTaskSuperseded, ReviewTaskClosure.superseded),
    (ErrorCodes.reviewTaskDecided, ReviewTaskClosure.decided),
    (ErrorCodes.reviewRoleRequired, ReviewTaskClosure.forbidden),
  ]) {
    test('error $code closes the task and blocks further submits', () async {
      final (c, repository, forbidden) = await controller();
      repository.decideErrors.add(ApiException('x', code: code));

      expect(
        await c.submit(verdict: 'approve', policyCodes: const []),
        isFalse,
      );
      expect(c.state.closure, closure);
      expect(c.state.error, isNull);
      expect(
        await c.submit(verdict: 'approve', policyCodes: const []),
        isFalse,
      );
      expect(await c.renew(), isFalse);

      expect(repository.decisions, hasLength(1));
      expect(forbidden, closure == ReviewTaskClosure.forbidden ? [1] : isEmpty);
      expect(reviewClosureMessage(closure), isNotEmpty);
    });
  }
}

class _FakeReviewRepository extends ReviewRepository {
  final ReviewTaskItem initial;
  ReviewTaskItem? renewed;
  final List<String> leaseCalls = [];
  final List<SubmitReviewDecisionReq> decisions = [];
  final List<Object> decideErrors = [];

  _FakeReviewRepository(this.initial);

  @override
  Future<ReviewTaskItem?> getTask(Object taskId) async => initial;

  @override
  Future<ReviewTaskItem?> renew(Object taskId, num leaseGeneration) async {
    leaseCalls.add('renew:$leaseGeneration');
    return renewed;
  }

  @override
  Future<void> release(Object taskId, num leaseGeneration) async {
    leaseCalls.add('release:$leaseGeneration');
  }

  @override
  Future<ReviewDecisionResp> decide(
    Object taskId,
    SubmitReviewDecisionReq req,
  ) async {
    decisions.add(req);
    if (decideErrors.isNotEmpty) throw decideErrors.removeAt(0);
    return ReviewDecisionResp(
      decisionId: 1,
      verdict: req.verdict,
      policyCodes: req.policyCodes,
      policyVersion: 'v',
    );
  }
}
