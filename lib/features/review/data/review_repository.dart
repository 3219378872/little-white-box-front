import 'dart:convert';
import 'dart:typed_data';

import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
import '../../../sdk/data/gateway.dart';

/// 审核工作台所用的 Gateway 接口（FX-111～FX-113）；服务端是唯一权限依据。
class ReviewRepository {
  const ReviewRepository();

  Future<ReviewerProfileResp> getProfile() {
    return apiCall<ReviewerProfileResp>(
      (ok, fail, eventually) =>
          gw.getReviewerProfile(ok: ok, fail: fail, eventually: eventually),
    );
  }

  Future<ReviewQueueResp> getQueue() {
    return apiCall<ReviewQueueResp>(
      (ok, fail, eventually) =>
          gw.getReviewQueue(ok: ok, fail: fail, eventually: eventually),
    );
  }

  /// 领取授权队列中的下一单；队列为空时返回 null。
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

  Future<ReviewTaskItem?> getTask(Object taskId) async {
    final resp = await apiCall<ReviewTaskResp>(
      (ok, fail, eventually) =>
          gw.getReviewTask(taskId, ok: ok, fail: fail, eventually: eventually),
    );
    return resp.found ? resp.task : null;
  }

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

class ReviewMediaContent {
  final String mimeType;
  final Uint8List bytes;

  const ReviewMediaContent({required this.mimeType, required this.bytes});

  bool get isImage => mimeType.startsWith('image/');
}
