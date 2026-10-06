import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 审核工作台所用的 Gateway 接口（FX-111～FX-113）；服务端是唯一权限依据。
class ReviewRepository {
  const ReviewRepository();

  /// 当前用户的审核员档案：是否启用、角色、市场与语言（GET /api/v2/review/me）。
  Future<ReviewerProfileResp> getProfile() {
    return apiCall<ReviewerProfileResp>(
      (ok, fail, eventually) =>
          gw.getReviewerProfile(ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 授权范围内各任务目的的待处理数与最久等待时长（GET /api/v2/review/queue）。
  Future<ReviewQueueResp> getQueue() {
    return apiCall<ReviewQueueResp>(
      (ok, fail, eventually) =>
          gw.getReviewQueue(ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 领取授权队列中的下一单；队列为空时返回 null。
  /// 对应 POST /api/v2/review/tasks/claim；[purpose] 为空时不按目的过滤。
  Future<ReviewTaskItem?> claim({String purpose = ''}) async {
    final resp = await apiCall<ReviewTaskResp>(
      (ok, fail, eventually) => gw.claimReviewTask(
        ClaimReviewTaskReq(purpose: purpose),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return resp.found ? resp.task : null;
  }

  /// 任务详情，含送审快照与机审阶段（GET /api/v2/review/tasks/{taskId}）；未找到时返回 null。
  Future<ReviewTaskItem?> getTask(Object taskId) async {
    final resp = await apiCall<ReviewTaskResp>(
      (ok, fail, eventually) =>
          gw.getReviewTask(taskId, ok: ok, fail: fail, eventually: eventually),
    );
    return resp.found ? resp.task : null;
  }

  /// 按 [leaseGeneration] 续期持有（POST /api/v2/review/tasks/{taskId}/renew），返回续期后的任务。
  Future<ReviewTaskItem?> renew(Object taskId, num leaseGeneration) async {
    final resp = await apiCall<ReviewTaskResp>(
      (ok, fail, eventually) => gw.renewReviewTask(
        taskId,
        ReviewLeaseReq(taskId: taskId, leaseGeneration: leaseGeneration),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return resp.found ? resp.task : null;
  }

  /// 放弃持有，任务回到队列（POST /api/v2/review/tasks/{taskId}/release）。
  Future<void> release(Object taskId, num leaseGeneration) {
    return apiCall<ReviewActionResp>(
      (ok, fail, eventually) => gw.releaseReviewTask(
        taskId,
        ReviewLeaseReq(taskId: taskId, leaseGeneration: leaseGeneration),
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 提交审核结论（POST /api/v2/review/tasks/{taskId}/decision）；请求携带持有代次与幂等键。
  Future<ReviewDecisionResp> decide(
    Object taskId,
    SubmitReviewDecisionReq req,
  ) {
    return apiCall<ReviewDecisionResp>(
      (ok, fail, eventually) => gw.submitReviewDecision(
        taskId,
        req,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
  }

  /// 经鉴权接口读取快照中的图片或证件。
  /// 对应 GET /api/v2/review/tasks/{taskId}/media/{mediaId}，内容以 base64 返回后在此解码。
  Future<ReviewMediaContent> media(Object taskId, Object mediaId) async {
    final resp = await apiCall<AdAssetContentResp>(
      (ok, fail, eventually) => gw.getReviewEvidenceMedia(
        taskId,
        mediaId,
        ok: ok,
        fail: fail,
        eventually: eventually,
      ),
    );
    return ReviewMediaContent(
      mimeType: resp.mimeType,
      bytes: base64Decode(resp.contentBase64),
    );
  }
}

/// 送审素材的类型与字节；非图片（如 PDF 证件）界面只展示类型与大小。
class ReviewMediaContent {
  final String mimeType;
  final Uint8List bytes;

  const ReviewMediaContent({required this.mimeType, required this.bytes});

  bool get isImage => mimeType.startsWith('image/');
}
