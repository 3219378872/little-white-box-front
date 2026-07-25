// --gateway--

class CommentItem {
  final num id;

  final num userId;

  final String userName;

  final String userAvatar;

  final num parentId;

  final num replyUserId;

  final String content;

  final num likeCount;

  final num createdAt;
  CommentItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.parentId,
    required this.replyUserId,
    required this.content,
    required this.likeCount,
    required this.createdAt,
  });
  factory CommentItem.fromJson(Map<String, dynamic> m) {
    return CommentItem(
      id: m['id'] ?? 0,
      userId: m['userId'] ?? 0,
      userName: m['userName'] ?? "",
      userAvatar: m['userAvatar'] ?? "",
      parentId: m['parentId'] ?? 0,
      replyUserId: m['replyUserId'] ?? 0,
      content: m['content'] ?? "",
      likeCount: m['likeCount'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'parentId': parentId,
      'replyUserId': replyUserId,
      'content': content,
      'likeCount': likeCount,
      'createdAt': createdAt,
    };
  }
}

class CreateCommentReq {
  final num postId;

  final num parentId;

  final num replyUserId;

  final String content;
  CreateCommentReq({
    required this.postId,
    required this.parentId,
    required this.replyUserId,
    required this.content,
  });
  factory CreateCommentReq.fromJson(Map<String, dynamic> m) {
    return CreateCommentReq(
      postId: m['postId'] ?? 0,
      parentId: m['parentId'] ?? 0,
      replyUserId: m['replyUserId'] ?? 0,
      content: m['content'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'parentId': parentId,
      'replyUserId': replyUserId,
      'content': content,
    };
  }
}

class CreateCommentResp {
  final num commentId;
  CreateCommentResp({required this.commentId});
  factory CreateCommentResp.fromJson(Map<String, dynamic> m) {
    return CreateCommentResp(commentId: m['commentId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'commentId': commentId};
  }
}

class CreatePostReq {
  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  // 0:草稿 1:发布
  final num status;
  CreatePostReq({
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.status,
  });
  factory CreatePostReq.fromJson(Map<String, dynamic> m) {
    return CreatePostReq(
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      status: m['status'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'status': status,
    };
  }
}

class CreatePostResp {
  final num postId;
  CreatePostResp({required this.postId});
  factory CreatePostResp.fromJson(Map<String, dynamic> m) {
    return CreatePostResp(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class DeleteCommentReq {
  final num commentId;
  DeleteCommentReq({required this.commentId});
  factory DeleteCommentReq.fromJson(Map<String, dynamic> m) {
    return DeleteCommentReq(commentId: m['commentId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'commentId': commentId};
  }
}

class DeleteCommentResp {
  DeleteCommentResp();
  factory DeleteCommentResp.fromJson(Map<String, dynamic> m) {
    return DeleteCommentResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class DeletePostReq {
  final num postId;
  DeletePostReq({required this.postId});
  factory DeletePostReq.fromJson(Map<String, dynamic> m) {
    return DeletePostReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class DeletePostResp {
  DeletePostResp();
  factory DeletePostResp.fromJson(Map<String, dynamic> m) {
    return DeletePostResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class FavoriteReq {
  final num postId;
  FavoriteReq({required this.postId});
  factory FavoriteReq.fromJson(Map<String, dynamic> m) {
    return FavoriteReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class FavoriteResp {
  FavoriteResp();
  factory FavoriteResp.fromJson(Map<String, dynamic> m) {
    return FavoriteResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class FollowReq {
  final num targetUserId;
  FollowReq({required this.targetUserId});
  factory FollowReq.fromJson(Map<String, dynamic> m) {
    return FollowReq(targetUserId: m['targetUserId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'targetUserId': targetUserId};
  }
}

class FollowResp {
  FollowResp();
  factory FollowResp.fromJson(Map<String, dynamic> m) {
    return FollowResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class GetCommentListReq {
  final num postId;

  final num page;

  final num pageSize;

  // 1:最新 2:最热
  final num sortBy;
  GetCommentListReq({
    required this.postId,
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetCommentListReq.fromJson(Map<String, dynamic> m) {
    return GetCommentListReq(
      postId: m['postId'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'page': page,
      'pageSize': pageSize,
      'sortBy': sortBy,
    };
  }
}

class GetCommentListResp {
  final List<CommentItem> list;

  final num total;

  final num page;

  final num pageSize;
  GetCommentListResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory GetCommentListResp.fromJson(Map<String, dynamic> m) {
    return GetCommentListResp(
      list: ((m['list'] ?? []) as List<dynamic>)
          .map((i) => CommentItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'list': list.map((i) => i.toJson()),
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class GetPostListReq {
  final num page;

  final num pageSize;

  // 1:最新 2:热门 3:推荐
  final num sortBy;
  GetPostListReq({
    required this.page,
    required this.pageSize,
    required this.sortBy,
  });
  factory GetPostListReq.fromJson(Map<String, dynamic> m) {
    return GetPostListReq(
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
      sortBy: m['sortBy'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'page': page, 'pageSize': pageSize, 'sortBy': sortBy};
  }
}

class GetPostListResp {
  final List<PostItem> list;

  final num total;

  final num page;

  final num pageSize;
  GetPostListResp({
    required this.list,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  factory GetPostListResp.fromJson(Map<String, dynamic> m) {
    return GetPostListResp(
      list: ((m['list'] ?? []) as List<dynamic>)
          .map((i) => PostItem.fromJson(i))
          .toList(),
      total: m['total'] ?? 0,
      page: m['page'] ?? 0,
      pageSize: m['pageSize'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'list': list.map((i) => i.toJson()),
      'total': total,
      'page': page,
      'pageSize': pageSize,
    };
  }
}

class GetPostReq {
  final num postId;
  GetPostReq({required this.postId});
  factory GetPostReq.fromJson(Map<String, dynamic> m) {
    return GetPostReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class GetPostResp {
  final num id;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num viewCount;

  final num likeCount;

  final num commentCount;

  final num favoriteCount;

  final bool isLiked;

  final bool isFavorited;

  final num createdAt;
  GetPostResp({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.commentCount,
    required this.favoriteCount,
    required this.isLiked,
    required this.isFavorited,
    required this.createdAt,
  });
  factory GetPostResp.fromJson(Map<String, dynamic> m) {
    return GetPostResp(
      id: m['id'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      commentCount: m['commentCount'] ?? 0,
      favoriteCount: m['favoriteCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
      isFavorited: m['isFavorited'] ?? false,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'favoriteCount': favoriteCount,
      'isLiked': isLiked,
      'isFavorited': isFavorited,
      'createdAt': createdAt,
    };
  }
}

class GetUserReq {
  final num userId;
  GetUserReq({required this.userId});
  factory GetUserReq.fromJson(Map<String, dynamic> m) {
    return GetUserReq(userId: m['userId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId};
  }
}

class GetUserResp {
  final num id;

  final String username;

  final String nickname;

  final String avatarUrl;

  final String bio;

  final num level;

  final num followerCount;

  final num followingCount;

  final num postCount;

  // 收藏列表可见性：true=公开，false=私密
  final bool favoritesVisible;
  GetUserResp({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
    required this.level,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.favoritesVisible,
  });
  factory GetUserResp.fromJson(Map<String, dynamic> m) {
    return GetUserResp(
      id: m['id'] ?? 0,
      username: m['username'] ?? "",
      nickname: m['nickname'] ?? "",
      avatarUrl: m['avatarUrl'] ?? "",
      bio: m['bio'] ?? "",
      level: m['level'] ?? 0,
      followerCount: m['followerCount'] ?? 0,
      followingCount: m['followingCount'] ?? 0,
      postCount: m['postCount'] ?? 0,
      favoritesVisible: m['favoritesVisible'] ?? true,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'nickname': nickname,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'level': level,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'postCount': postCount,
      'favoritesVisible': favoritesVisible,
    };
  }
}

class HealthReq {
  HealthReq();
  factory HealthReq.fromJson(Map<String, dynamic> m) {
    return HealthReq();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class HealthResp {
  final String status;
  HealthResp({required this.status});
  factory HealthResp.fromJson(Map<String, dynamic> m) {
    return HealthResp(status: m['status'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'status': status};
  }
}

class LikeReq {
  final num targetId;

  // 1:帖子 2:评论
  final num targetType;
  LikeReq({required this.targetId, required this.targetType});
  factory LikeReq.fromJson(Map<String, dynamic> m) {
    return LikeReq(
      targetId: m['targetId'] ?? 0,
      targetType: m['targetType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'targetId': targetId, 'targetType': targetType};
  }
}

class LikeResp {
  LikeResp();
  factory LikeResp.fromJson(Map<String, dynamic> m) {
    return LikeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class LoginReq {
  final String username;

  final String password;

  final String phone;

  final String verifyCode;

  // 1:密码登录 2:验证码登录
  final num loginType;
  LoginReq({
    required this.username,
    required this.password,
    required this.phone,
    required this.verifyCode,
    required this.loginType,
  });
  factory LoginReq.fromJson(Map<String, dynamic> m) {
    return LoginReq(
      username: m['username'] ?? "",
      password: m['password'] ?? "",
      phone: m['phone'] ?? "",
      verifyCode: m['verifyCode'] ?? "",
      loginType: m['loginType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phone': phone,
      'verifyCode': verifyCode,
      'loginType': loginType,
    };
  }
}

class LoginResp {
  final num userId;

  final String token;
  LoginResp({required this.userId, required this.token});
  factory LoginResp.fromJson(Map<String, dynamic> m) {
    return LoginResp(userId: m['userId'] ?? 0, token: m['token'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token};
  }
}

class PostItem {
  final num id;

  final num authorId;

  final String authorName;

  final String authorAvatar;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;

  final num viewCount;

  final num likeCount;

  final bool isLiked;

  final num commentCount;

  final num createdAt;
  PostItem({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
    required this.viewCount,
    required this.likeCount,
    required this.isLiked,
    required this.commentCount,
    required this.createdAt,
  });
  factory PostItem.fromJson(Map<String, dynamic> m) {
    return PostItem(
      id: m['id'] ?? 0,
      authorId: m['authorId'] ?? 0,
      authorName: m['authorName'] ?? "",
      authorAvatar: m['authorAvatar'] ?? "",
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
      viewCount: m['viewCount'] ?? 0,
      likeCount: m['likeCount'] ?? 0,
      isLiked: m['isLiked'] ?? false,
      commentCount: m['commentCount'] ?? 0,
      createdAt: m['createdAt'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
      'viewCount': viewCount,
      'likeCount': likeCount,
      'isLiked': isLiked,
      'commentCount': commentCount,
      'createdAt': createdAt,
    };
  }
}

class RegisterReq {
  final String username;

  final String password;

  final String phone;

  final String verifyCode;
  RegisterReq({
    required this.username,
    required this.password,
    required this.phone,
    required this.verifyCode,
  });
  factory RegisterReq.fromJson(Map<String, dynamic> m) {
    return RegisterReq(
      username: m['username'] ?? "",
      password: m['password'] ?? "",
      phone: m['phone'] ?? "",
      verifyCode: m['verifyCode'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'phone': phone,
      'verifyCode': verifyCode,
    };
  }
}

class RegisterResp {
  final num userId;

  final String token;
  RegisterResp({required this.userId, required this.token});
  factory RegisterResp.fromJson(Map<String, dynamic> m) {
    return RegisterResp(userId: m['userId'] ?? 0, token: m['token'] ?? "");
  }
  Map<String, dynamic> toJson() {
    return {'userId': userId, 'token': token};
  }
}

class SendVerifyCodeReq {
  final String phone;

  // 1:注册 2:登录 3:重置密码
  final num type;
  SendVerifyCodeReq({required this.phone, required this.type});
  factory SendVerifyCodeReq.fromJson(Map<String, dynamic> m) {
    return SendVerifyCodeReq(phone: m['phone'] ?? "", type: m['type'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'phone': phone, 'type': type};
  }
}

class SendVerifyCodeResp {
  SendVerifyCodeResp();
  factory SendVerifyCodeResp.fromJson(Map<String, dynamic> m) {
    return SendVerifyCodeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnfavoriteReq {
  final num postId;
  UnfavoriteReq({required this.postId});
  factory UnfavoriteReq.fromJson(Map<String, dynamic> m) {
    return UnfavoriteReq(postId: m['postId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'postId': postId};
  }
}

class UnfavoriteResp {
  UnfavoriteResp();
  factory UnfavoriteResp.fromJson(Map<String, dynamic> m) {
    return UnfavoriteResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnfollowReq {
  final num targetUserId;
  UnfollowReq({required this.targetUserId});
  factory UnfollowReq.fromJson(Map<String, dynamic> m) {
    return UnfollowReq(targetUserId: m['targetUserId'] ?? 0);
  }
  Map<String, dynamic> toJson() {
    return {'targetUserId': targetUserId};
  }
}

class UnfollowResp {
  UnfollowResp();
  factory UnfollowResp.fromJson(Map<String, dynamic> m) {
    return UnfollowResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UnlikeReq {
  final num targetId;

  final num targetType;
  UnlikeReq({required this.targetId, required this.targetType});
  factory UnlikeReq.fromJson(Map<String, dynamic> m) {
    return UnlikeReq(
      targetId: m['targetId'] ?? 0,
      targetType: m['targetType'] ?? 0,
    );
  }
  Map<String, dynamic> toJson() {
    return {'targetId': targetId, 'targetType': targetType};
  }
}

class UnlikeResp {
  UnlikeResp();
  factory UnlikeResp.fromJson(Map<String, dynamic> m) {
    return UnlikeResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UpdatePostReq {
  final num postId;

  final String title;

  final String content;

  final List<String> images;

  final List<String> tags;
  UpdatePostReq({
    required this.postId,
    required this.title,
    required this.content,
    required this.images,
    required this.tags,
  });
  factory UpdatePostReq.fromJson(Map<String, dynamic> m) {
    return UpdatePostReq(
      postId: m['postId'] ?? 0,
      title: m['title'] ?? "",
      content: m['content'] ?? "",
      images: m['images']?.cast<String>() ?? [],
      tags: m['tags']?.cast<String>() ?? [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'postId': postId,
      'title': title,
      'content': content,
      'images': images,
      'tags': tags,
    };
  }
}

class UpdatePostResp {
  UpdatePostResp();
  factory UpdatePostResp.fromJson(Map<String, dynamic> m) {
    return UpdatePostResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UpdateProfileReq {
  final String nickname;

  final String avatarUrl;

  final String bio;
  UpdateProfileReq({
    required this.nickname,
    required this.avatarUrl,
    required this.bio,
  });
  factory UpdateProfileReq.fromJson(Map<String, dynamic> m) {
    return UpdateProfileReq(
      nickname: m['nickname'] ?? "",
      avatarUrl: m['avatarUrl'] ?? "",
      bio: m['bio'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'nickname': nickname, 'avatarUrl': avatarUrl, 'bio': bio};
  }
}

class UpdateProfileResp {
  UpdateProfileResp();
  factory UpdateProfileResp.fromJson(Map<String, dynamic> m) {
    return UpdateProfileResp();
  }
  Map<String, dynamic> toJson() {
    return {};
  }
}

class UploadImageReq {
  final List<int> file;
  UploadImageReq({required this.file});
  factory UploadImageReq.fromJson(Map<String, dynamic> m) {
    return UploadImageReq(file: m['file']?.cast<int>() ?? []);
  }
  Map<String, dynamic> toJson() {
    return {'file': file};
  }
}

class UploadImageResp {
  final num mediaId;

  final String url;

  final String thumbnailUrl;
  UploadImageResp({
    required this.mediaId,
    required this.url,
    required this.thumbnailUrl,
  });
  factory UploadImageResp.fromJson(Map<String, dynamic> m) {
    return UploadImageResp(
      mediaId: m['mediaId'] ?? 0,
      url: m['url'] ?? "",
      thumbnailUrl: m['thumbnailUrl'] ?? "",
    );
  }
  Map<String, dynamic> toJson() {
    return {'mediaId': mediaId, 'url': url, 'thumbnailUrl': thumbnailUrl};
  }
}
