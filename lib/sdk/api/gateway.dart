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
  int commentId,
  DeleteCommentReq request, {
  Function(DeleteCommentResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/comment/${commentId}",
    request,
    ok: (data) {
      if (ok != null) ok(DeleteCommentResp.fromJson(data));
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
  int postId, {
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
  await apiPost(
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
  await apiPost(
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

/// --/api/v1/post--
///
/// request: CreatePostReq
/// response: CreatePostResp
Future createPost(
  CreatePostReq request, {
  Function(CreatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/post",
    request,
    ok: (data) {
      if (ok != null) ok(CreatePostResp.fromJson(data));
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
  int postId, {
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

/// --/api/v1/post/:postId--
///
/// request: UpdatePostReq
/// response: UpdatePostResp
Future updatePost(
  int postId,
  UpdatePostReq request, {
  Function(UpdatePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/post/${postId}",
    request,
    ok: (data) {
      if (ok != null) ok(UpdatePostResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}

/// --/api/v1/post/:postId--
///
/// request: DeletePostReq
/// response: DeletePostResp
Future deletePost(
  int postId,
  DeletePostReq request, {
  Function(DeletePostResp)? ok,
  Function(String)? fail,
  Function? eventually,
}) async {
  await apiPost(
    "/api/v1/post/${postId}",
    request,
    ok: (data) {
      if (ok != null) ok(DeletePostResp.fromJson(data));
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

/// --/api/v1/user/:userId--
///
/// request: GetUserReq
/// response: GetUserResp
Future getUser(
  int userId, {
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
  await apiPost(
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
  await apiPost(
    "/api/v1/user/profile",
    request,
    ok: (data) {
      if (ok != null) ok(UpdateProfileResp.fromJson(data));
    },
    fail: fail,
    eventually: eventually,
  );
}
