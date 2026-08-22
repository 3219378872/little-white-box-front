import 'api.dart';
import '../data/gateway.dart';

/// gateway

/// --/api/v1/health--
///
/// request: HealthReq
/// response: HealthResp
Future health({
  Function(HealthResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/health",
    ok: (data) {
      if (ok != null) ok(HealthResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/health/ready--
///
/// request: HealthReq
/// response: HealthReadyResp
Future healthReady({
  Function(HealthReadyResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/health/ready",
    ok: (data) {
      if (ok != null) ok(HealthReadyResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/assistant/chat--
///
/// request: AssistantChatReq
/// response: AssistantChatEvent
Future assistantChat(
  AssistantChatReq request, {
  Function(AssistantChatEvent)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/assistant/chat",
    request,
    ok: (data) {
      if (ok != null) ok(AssistantChatEvent.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/behavior/events--
///
/// request: RecordBehaviorEventsReq
/// response: RecordBehaviorEventsResp
Future recordBehaviorEvents(
  RecordBehaviorEventsReq request, {
  Function(RecordBehaviorEventsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/behavior/events",
    request,
    ok: (data) {
      if (ok != null) ok(RecordBehaviorEventsResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/comments/:commentId/replies--
///
/// request: GetCommentRepliesReq
/// response: GetCommentRepliesResp
Future getCommentReplies(
  Object commentId, {
  Function(GetCommentRepliesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/comments/${commentId}/replies",
    ok: (data) {
      if (ok != null) ok(GetCommentRepliesResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/comments/:postId--
///
/// request: GetCommentListReq
/// response: GetCommentListResp
Future getCommentList(
  Object postId, {
  Function(GetCommentListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/comments/${postId}",
    ok: (data) {
      if (ok != null) ok(GetCommentListResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/comment--
///
/// request: CreateCommentReq
/// response: CreateCommentResp
Future createComment(
  CreateCommentReq request, {
  Function(CreateCommentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/comment",
    request,
    ok: (data) {
      if (ok != null) ok(CreateCommentResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/comment/:commentId--
///
/// request: DeleteCommentReq
/// response: DeleteCommentResp
Future deleteComment(
  Object commentId,
  DeleteCommentReq request, {
  Function(DeleteCommentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiDelete(
    "/api/v1/comment/${commentId}",
    request,
    ok: (data) {
      if (ok != null) ok(DeleteCommentResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/feed/follow--
///
/// request: GetFollowFeedReq
/// response: GetFollowFeedResp
Future getFollowFeed({
  Function(GetFollowFeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/feed/follow",
    ok: (data) {
      if (ok != null) ok(GetFollowFeedResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/feed/recommend--
///
/// request: GetRecommendFeedReq
/// response: GetRecommendFeedResp
Future getRecommendFeed({
  Function(GetRecommendFeedResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/feed/recommend",
    ok: (data) {
      if (ok != null) ok(GetRecommendFeedResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/media/image--
///
/// request: UploadImageReq
/// response: UploadImageResp
Future uploadImage(
  UploadImageReq request, {
  Function(UploadImageResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/media/image",
    request,
    ok: (data) {
      if (ok != null) ok(UploadImageResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/favorite--
///
/// request: FavoriteReq
/// response: FavoriteResp
Future favorite(
  FavoriteReq request, {
  Function(FavoriteResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/favorite",
    request,
    ok: (data) {
      if (ok != null) ok(FavoriteResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/favorite--
///
/// request: UnfavoriteReq
/// response: UnfavoriteResp
Future unfavorite(
  UnfavoriteReq request, {
  Function(UnfavoriteResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiDelete(
    "/api/v1/favorite",
    request,
    ok: (data) {
      if (ok != null) ok(UnfavoriteResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/like--
///
/// request: LikeReq
/// response: LikeResp
Future like(
  LikeReq request, {
  Function(LikeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/like",
    request,
    ok: (data) {
      if (ok != null) ok(LikeResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/like--
///
/// request: UnlikeReq
/// response: UnlikeResp
Future unlike(
  UnlikeReq request, {
  Function(UnlikeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiDelete(
    "/api/v1/like",
    request,
    ok: (data) {
      if (ok != null) ok(UnlikeResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/auth/login--
///
/// request: LoginReq
/// response: LoginResp
Future login(
  LoginReq request, {
  Function(LoginResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/auth/login",
    request,
    ok: (data) {
      if (ok != null) ok(LoginResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/auth/refresh--
///
/// request: RefreshTokenReq
/// response: RefreshTokenResp
Future refreshToken(
  RefreshTokenReq request, {
  Function(RefreshTokenResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/auth/refresh",
    request,
    ok: (data) {
      if (ok != null) ok(RefreshTokenResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/auth/register--
///
/// request: RegisterReq
/// response: RegisterResp
Future register(
  RegisterReq request, {
  Function(RegisterResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/auth/register",
    request,
    ok: (data) {
      if (ok != null) ok(RegisterResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/auth/verify-code--
///
/// request: SendVerifyCodeReq
/// response: SendVerifyCodeResp
Future sendVerifyCode(
  SendVerifyCodeReq request, {
  Function(SendVerifyCodeResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/auth/verify-code",
    request,
    ok: (data) {
      if (ok != null) ok(SendVerifyCodeResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/messages--
///
/// request: SendMessageReq
/// response: SendMessageResp
Future sendMessage(
  SendMessageReq request, {
  Function(SendMessageResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/messages",
    request,
    ok: (data) {
      if (ok != null) ok(SendMessageResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/messages/conversations--
///
/// request: GetConversationsReq
/// response: GetConversationsResp
Future getConversations({
  Function(GetConversationsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/messages/conversations",
    ok: (data) {
      if (ok != null) ok(GetConversationsResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/messages/conversations/:id--
///
/// request: GetMessagesReq
/// response: GetMessagesResp
Future getMessages(
  Object id, {
  Function(GetMessagesResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/messages/conversations/${id}",
    ok: (data) {
      if (ok != null) ok(GetMessagesResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/messages/conversations/:id/read--
///
/// request: MarkConversationReadReq
/// response: MarkConversationReadResp
Future markConversationRead(
  Object id,
  MarkConversationReadReq request, {
  Function(MarkConversationReadResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/messages/conversations/${id}/read",
    request,
    ok: (data) {
      if (ok != null) ok(MarkConversationReadResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/messages/unread--
///
/// request:
/// response: GetUnreadSummaryResp
Future getUnreadSummary({
  Function(GetUnreadSummaryResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/messages/unread",
    ok: (data) {
      if (ok != null) ok(GetUnreadSummaryResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/post/:postId--
///
/// request: GetPostReq
/// response: GetPostResp
Future getPost(
  Object postId, {
  Function(GetPostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/post/${postId}",
    ok: (data) {
      if (ok != null) ok(GetPostResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/posts--
///
/// request: GetPostListReq
/// response: GetPostListResp
Future getPostList({
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/posts",
    ok: (data) {
      if (ok != null) ok(GetPostListResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/post--
///
/// request: CreatePostReq
/// response: CreatePostResp
Future createPostV2(
  CreatePostReq request, {
  Function(CreatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v2/post",
    request,
    ok: (data) {
      if (ok != null) ok(CreatePostResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/post/:postId--
///
/// request: UpdatePostV2Req
/// response: UpdatePostResp
Future updatePostV2(
  Object postId,
  UpdatePostV2Req request, {
  Function(UpdatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPut(
    "/api/v2/post/${postId}",
    request,
    ok: (data) {
      if (ok != null) ok(UpdatePostResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/post/:postId--
///
/// request: DeletePostV2Req
/// response: DeletePostResp
Future deletePostV2(
  Object postId,
  DeletePostV2Req request, {
  Function(DeletePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiDelete(
    "/api/v2/post/${postId}",
    request,
    ok: (data) {
      if (ok != null) ok(DeletePostResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/search--
///
/// request: SearchReq
/// response: SearchResp
Future search({
  Function(SearchResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/search",
    ok: (data) {
      if (ok != null) ok(SearchResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/search/tags--
///
/// request: SearchTagsReq
/// response: SearchTagsResp
Future searchTags({
  Function(SearchTagsResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/search/tags",
    ok: (data) {
      if (ok != null) ok(SearchTagsResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/search/users--
///
/// request: SearchUsersReq
/// response: SearchUsersResp
Future searchUsers({
  Function(SearchUsersResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/search/users",
    ok: (data) {
      if (ok != null) ok(SearchUsersResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/user/:userId--
///
/// request: GetUserReq
/// response: GetUserResp
Future getUser(
  Object userId, {
  Function(GetUserResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/user/${userId}",
    ok: (data) {
      if (ok != null) ok(GetUserResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/users/:userId/favorites--
///
/// request: GetUserFavoritesReq
/// response: GetPostListResp
Future getUserFavorites(
  Object userId, {
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/users/${userId}/favorites",
    ok: (data) {
      if (ok != null) ok(GetPostListResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/users/:userId/posts--
///
/// request: GetUserPostsReq
/// response: GetPostListResp
Future getUserPosts(
  Object userId, {
  Function(GetPostListResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v1/users/${userId}/posts",
    ok: (data) {
      if (ok != null) ok(GetPostListResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/user/follow--
///
/// request: FollowReq
/// response: FollowResp
Future follow(
  FollowReq request, {
  Function(FollowResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/user/follow",
    request,
    ok: (data) {
      if (ok != null) ok(FollowResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/user/follow--
///
/// request: UnfollowReq
/// response: UnfollowResp
Future unfollow(
  UnfollowReq request, {
  Function(UnfollowResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiDelete(
    "/api/v1/user/follow",
    request,
    ok: (data) {
      if (ok != null) ok(UnfollowResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/user/profile--
///
/// request: UpdateProfileReq
/// response: UpdateProfileResp
Future updateProfile(
  UpdateProfileReq request, {
  Function(UpdateProfileResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPut(
    "/api/v1/user/profile",
    request,
    ok: (data) {
      if (ok != null) ok(UpdateProfileResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/me/personalization--
///
/// request:
/// response: GetPersonalizationPreferenceResp
Future getPersonalizationPreference({
  Function(GetPersonalizationPreferenceResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiGet(
    "/api/v2/me/personalization",
    ok: (data) {
      if (ok != null) ok(GetPersonalizationPreferenceResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v2/me/personalization--
///
/// request: SetPersonalizationPreferenceReq
/// response: SetPersonalizationPreferenceResp
Future setPersonalizationPreference(
  SetPersonalizationPreferenceReq request, {
  Function(SetPersonalizationPreferenceResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPut(
    "/api/v2/me/personalization",
    request,
    ok: (data) {
      if (ok != null) ok(SetPersonalizationPreferenceResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}
