// Generated from app/gateway/openapi.yaml. DO NOT EDIT.

import 'api.dart';
import '../data/gateway.dart';

Future health({
  Function(HealthResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/health";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          HealthResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future healthReady({
  Function(HealthReadyResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/health/ready";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          HealthReadyResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getPostList({
  GetPostListReq? request,
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v1/posts";
  if (request != null) {
    final allowed = <String>{'pageSize', 'sortBy', 'cursor'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetPostListResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getPost(
  Object postId, {
  Function(GetPostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/post/${Uri.encodeComponent(postId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetPostResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future register(
  RegisterReq request, {
  Function(RegisterResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/auth/register";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          RegisterResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future login(
  LoginReq request, {
  Function(LoginResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/auth/login";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          LoginResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future sendVerifyCode(
  SendVerifyCodeReq request, {
  Function(SendVerifyCodeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/auth/verify-code";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          SendVerifyCodeResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future refreshToken(
  RefreshTokenReq request, {
  Function(RefreshTokenResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/auth/refresh";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          RefreshTokenResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getUser(
  Object userId, {
  Function(GetUserResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/user/${Uri.encodeComponent(userId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetUserResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getUserPosts(
  Object userId, {
  GetUserPostsReq? request,
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v1/users/${Uri.encodeComponent(userId.toString())}/posts";
  if (request != null) {
    final allowed = <String>{'pageSize', 'sortBy', 'cursor'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetPostListResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getUserFavorites(
  Object userId, {
  GetUserFavoritesReq? request,
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v1/users/${Uri.encodeComponent(userId.toString())}/favorites";
  if (request != null) {
    final allowed = <String>{'page', 'pageSize', 'cursor'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetPostListResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future updateProfile(
  UpdateProfileReq request, {
  Function(UpdateProfileResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/user/profile";
  await apiPut(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UpdateProfileResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future follow(
  FollowReq request, {
  Function(FollowResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/user/follow";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          FollowResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future unfollow(
  UnfollowReq request, {
  Function(UnfollowResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/user/follow";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UnfollowResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future createPostV2(
  CreatePostReq request, {
  Function(CreatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/post";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          CreatePostResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future updatePostV2(
  Object postId,
  UpdatePostV2Req request, {
  Function(UpdatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/post/${Uri.encodeComponent(postId.toString())}";
  await apiPut(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UpdatePostResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future deletePostV2(
  Object postId,
  DeletePostV2Req request, {
  Function(DeletePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/post/${Uri.encodeComponent(postId.toString())}";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          DeletePostResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getCommentList(
  Object postId, {
  GetCommentListReq? request,
  Function(GetCommentListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v1/comments/${Uri.encodeComponent(postId.toString())}";
  if (request != null) {
    final allowed = <String>{'page', 'pageSize', 'sortBy'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetCommentListResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getCommentReplies(
  Object commentId, {
  GetCommentRepliesReq? request,
  Function(GetCommentRepliesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url =
      "/api/v1/comments/${Uri.encodeComponent(commentId.toString())}/replies";
  if (request != null) {
    final allowed = <String>{'page', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetCommentRepliesResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future createComment(
  CreateCommentReq request, {
  Function(CreateCommentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/comment";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          CreateCommentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future deleteComment(
  Object commentId,
  DeleteCommentReq request, {
  Function(DeleteCommentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/comment/${Uri.encodeComponent(commentId.toString())}";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          DeleteCommentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future like(
  LikeReq request, {
  Function(LikeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/like";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          LikeResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future unlike(
  UnlikeReq request, {
  Function(UnlikeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/like";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UnlikeResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future favorite(
  FavoriteReq request, {
  Function(FavoriteResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/favorite";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          FavoriteResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future unfavorite(
  UnfavoriteReq request, {
  Function(UnfavoriteResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v1/favorite";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UnfavoriteResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

const uploadImagePath = "/api/v1/media/image";

const uploadVideoPath = "/api/v1/media/video";

const uploadAudioPath = "/api/v1/media/audio";

Future recordBehaviorEvents(
  RecordBehaviorEventsReq request, {
  Function(RecordBehaviorEventsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/behavior/events";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          RecordBehaviorEventsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getFollowFeed({
  GetFollowFeedReq? request,
  Function(GetFollowFeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/feed/follow";
  if (request != null) {
    final allowed = <String>{'cursorCreatedAt', 'cursorPostId', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetFollowFeedResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getRecommendFeed({
  GetRecommendFeedReq? request,
  Function(GetRecommendFeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/feed/recommend";
  if (request != null) {
    final allowed = <String>{
      'anonymousId',
      'scene',
      'requestId',
      'sessionId',
      'cursor',
      'pageSize',
      'experimentId',
      'adSlots',
      'market',
    };
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetRecommendFeedResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future search({
  SearchReq? request,
  Function(SearchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/search";
  if (request != null) {
    final allowed = <String>{'keyword', 'page', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          SearchResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future searchUsers({
  SearchUsersReq? request,
  Function(SearchUsersResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/search/users";
  if (request != null) {
    final allowed = <String>{'keyword', 'page', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          SearchUsersResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future searchTags({
  SearchTagsReq? request,
  Function(SearchTagsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/search/tags";
  if (request != null) {
    final allowed = <String>{'keyword', 'limit'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          SearchTagsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getConversations({
  GetConversationsReq? request,
  Function(GetConversationsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/messages/conversations";
  if (request != null) {
    final allowed = <String>{'page', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetConversationsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getMessages(
  Object id, {
  GetMessagesReq? request,
  Function(GetMessagesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url =
      "/api/v2/messages/conversations/${Uri.encodeComponent(id.toString())}";
  if (request != null) {
    final allowed = <String>{'lastId', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetMessagesResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future sendMessage(
  SendMessageReq request, {
  Function(SendMessageResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/messages";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          SendMessageResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future markConversationRead(
  Object id,
  MarkConversationReadReq request, {
  Function(MarkConversationReadResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/messages/conversations/${Uri.encodeComponent(id.toString())}/read";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          MarkConversationReadResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getUnreadSummary({
  Function(GetUnreadSummaryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/messages/unread";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetUnreadSummaryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

String assistantRunEventsPath(Object id) =>
    "/api/v2/assistant/runs/${Uri.encodeComponent(id.toString())}/events";

Future getAgentConsent({
  Function(GetAgentConsentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/consent";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetAgentConsentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future setAgentConsent(
  SetAgentConsentReq request, {
  Function(SetAgentConsentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/consent";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          SetAgentConsentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getAssistantThread({
  Function(GetAssistantThreadResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/thread";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetAssistantThreadResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listAssistantMessages({
  ListAssistantMessagesReq? request,
  Function(ListAssistantMessagesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/assistant/messages";
  if (request != null) {
    final allowed = <String>{'sessionId', 'afterId', 'beforeId', 'limit'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListAssistantMessagesResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future postAssistantMessage(
  PostAssistantMessageReq request, {
  Function(PostAssistantMessageResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/messages";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          PostAssistantMessageResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future markAssistantThreadRead({
  Function(MarkAssistantThreadReadResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/thread/read";
  await apiPost(
    url,
    const {},
    ok: (data) {
      if (ok != null)
        ok(
          MarkAssistantThreadReadResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future deleteAssistantHistory({
  Function(DeleteAssistantHistoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/history";
  await apiDelete(
    url,
    const {},
    ok: (data) {
      if (ok != null)
        ok(
          DeleteAssistantHistoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future cancelAssistantRun(
  Object id,
  CancelAssistantRunReq request, {
  Function(CancelAssistantRunResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/assistant/runs/${Uri.encodeComponent(id.toString())}/cancel";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          CancelAssistantRunResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future confirmAssistantRun(
  Object id,
  ConfirmAssistantRunReq request, {
  Function(ConfirmAssistantRunResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/assistant/runs/${Uri.encodeComponent(id.toString())}/confirm";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ConfirmAssistantRunResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future answerAssistantQuestions(
  Object id,
  AnswerAssistantQuestionsReq request, {
  Function(AnswerAssistantQuestionsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/assistant/runs/${Uri.encodeComponent(id.toString())}/answers";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AnswerAssistantQuestionsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listAssistantMemory({
  ListAssistantMemoryReq? request,
  Function(ListAssistantMemoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/assistant/memory";
  if (request != null) {
    final allowed = <String>{'target'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListAssistantMemoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future addAssistantMemory(
  AddAssistantMemoryReq request, {
  Function(AddAssistantMemoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/memory";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AddAssistantMemoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future replaceAssistantMemory(
  Object id,
  ReplaceAssistantMemoryReq request, {
  Function(ReplaceAssistantMemoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/memory/${Uri.encodeComponent(id.toString())}";
  await apiPatch(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReplaceAssistantMemoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future removeAssistantMemory(
  Object id,
  RemoveAssistantMemoryReq request, {
  Function(RemoveAssistantMemoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/memory/${Uri.encodeComponent(id.toString())}";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          RemoveAssistantMemoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future batchAssistantMemory(
  BatchAssistantMemoryReq request, {
  Function(BatchAssistantMemoryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/memory/batch";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          BatchAssistantMemoryResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future undoAssistantMemoryChange(
  Object id,
  UndoAssistantMemoryChangeReq request, {
  Function(UndoAssistantMemoryChangeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/assistant/memory/changes/${Uri.encodeComponent(id.toString())}/undo";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UndoAssistantMemoryChangeResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listAssistantWatch({
  Function(ListAssistantWatchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/watch";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListAssistantWatchResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future createAssistantWatch(
  CreateAssistantWatchReq request, {
  Function(CreateAssistantWatchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/watch";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          CreateAssistantWatchResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future updateAssistantWatch(
  Object id,
  UpdateAssistantWatchReq request, {
  Function(UpdateAssistantWatchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/watch/${Uri.encodeComponent(id.toString())}";
  await apiPatch(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          UpdateAssistantWatchResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future deleteAssistantWatch(
  Object id,
  DeleteAssistantWatchReq request, {
  Function(DeleteAssistantWatchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/watch/${Uri.encodeComponent(id.toString())}";
  await apiDelete(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          DeleteAssistantWatchResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future submitAssistantRecommendFeedback(
  AssistantRecommendFeedbackReq request, {
  Function(AssistantRecommendFeedbackResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/assistant/recommend/feedback";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AssistantRecommendFeedbackResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getPersonalizationPreference({
  Function(GetPersonalizationPreferenceResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/me/personalization";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          GetPersonalizationPreferenceResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future setPersonalizationPreference(
  SetPersonalizationPreferenceReq request, {
  Function(SetPersonalizationPreferenceResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/me/personalization";
  await apiPut(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          SetPersonalizationPreferenceResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getMyAdvertiser({
  Function(AdvertiserResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/advertiser";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          AdvertiserResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future applyAdvertiser(
  ApplyAdvertiserReq request, {
  Function(AdvertiserResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/advertiser";
  await apiPut(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdvertiserResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future addAdQualification(
  AddQualificationReq request, {
  Function(AdvertiserResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/advertiser/qualifications";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdvertiserResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

String uploadAdAssetPath(Object kind) =>
    "/api/v2/ads/assets/${Uri.encodeComponent(kind.toString())}";

Future getAdAsset(
  Object assetId, {
  Function(AdAssetContentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/assets/${Uri.encodeComponent(assetId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          AdAssetContentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listAdPolicies({
  Function(ListAdPoliciesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/policies";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListAdPoliciesResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listAds({
  ListAdsReq? request,
  Function(ListAdsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/ads";
  if (request != null) {
    final allowed = <String>{'cursor', 'pageSize'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListAdsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future createAd(
  CreateAdReq request, {
  Function(AdResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdResp.fromJson(Map<String, dynamic>.from(data as Map? ?? const {})),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getAd(
  Object adId, {
  Function(AdResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/${Uri.encodeComponent(adId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          AdResp.fromJson(Map<String, dynamic>.from(data as Map? ?? const {})),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future updateAd(
  Object adId,
  UpdateAdReq request, {
  Function(AdResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/${Uri.encodeComponent(adId.toString())}";
  await apiPut(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdResp.fromJson(Map<String, dynamic>.from(data as Map? ?? const {})),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future hideAd(
  Object adId,
  HideAdReq request, {
  Function(AdActionResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/${Uri.encodeComponent(adId.toString())}/hide";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdActionResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future reportAd(
  Object adId,
  ReportAdReq request, {
  Function(ReportAdResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/${Uri.encodeComponent(adId.toString())}/report";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReportAdResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future appealAd(
  Object adId,
  AppealAdReq request, {
  Function(AdResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/ads/${Uri.encodeComponent(adId.toString())}/appeal";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          AdResp.fromJson(Map<String, dynamic>.from(data as Map? ?? const {})),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getReviewerProfile({
  Function(ReviewerProfileResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/review/me";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewerProfileResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getReviewQueue({
  Function(ReviewQueueResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/review/queue";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewQueueResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future claimReviewTask(
  ClaimReviewTaskReq request, {
  Function(ReviewTaskResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/review/tasks/claim";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewTaskResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getReviewTask(
  Object taskId, {
  Function(ReviewTaskResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url = "/api/v2/review/tasks/${Uri.encodeComponent(taskId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewTaskResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future renewReviewTask(
  Object taskId,
  ReviewLeaseReq request, {
  Function(ReviewTaskResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/tasks/${Uri.encodeComponent(taskId.toString())}/renew";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewTaskResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future releaseReviewTask(
  Object taskId,
  ReviewLeaseReq request, {
  Function(ReviewActionResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/tasks/${Uri.encodeComponent(taskId.toString())}/release";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewActionResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future submitReviewDecision(
  Object taskId,
  SubmitReviewDecisionReq request, {
  Function(ReviewDecisionResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/tasks/${Uri.encodeComponent(taskId.toString())}/decision";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewDecisionResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future getReviewEvidenceMedia(
  Object taskId,
  Object mediaId, {
  Function(AdAssetContentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/tasks/${Uri.encodeComponent(taskId.toString())}/media/${Uri.encodeComponent(mediaId.toString())}";
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          AdAssetContentResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future listReviewSeeds({
  ListReviewSeedsReq? request,
  Function(ListReviewSeedsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  var url = "/api/v2/review/seeds";
  if (request != null) {
    final allowed = <String>{'status', 'limit'};
    final query = request.toJson()
      ..removeWhere((k, v) => !allowed.contains(k) || v == null);
    url = Uri.parse(url)
        .replace(
          queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
        )
        .toString();
  }
  await apiGet(
    url,
    ok: (data) {
      if (ok != null)
        ok(
          ListReviewSeedsResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future confirmReviewSeed(
  Object seedId,
  ReviewSeedActionReq request, {
  Function(ReviewSeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/seeds/${Uri.encodeComponent(seedId.toString())}/confirm";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewSeedResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}

Future retireReviewSeed(
  Object seedId,
  ReviewSeedActionReq request, {
  Function(ReviewSeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  final url =
      "/api/v2/review/seeds/${Uri.encodeComponent(seedId.toString())}/retire";
  await apiPost(
    url,
    request,
    ok: (data) {
      if (ok != null)
        ok(
          ReviewSeedResp.fromJson(
            Map<String, dynamic>.from(data as Map? ?? const {}),
          ),
        );
    },
    fail: fail,
    eventually: eventually,
  );
}
