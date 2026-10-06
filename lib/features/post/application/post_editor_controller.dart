import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/legacy.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/api/image_mime.dart';
import '../../../core/api/json_int64.dart';
import '../../../sdk/data/gateway.dart';
import '../data/post_repository.dart';
import 'post_dependencies.dart';

/// 标题、正文与标签的长度上限，与后端发帖校验一致；页面输入框复用同一组值。
const postTitleMaxLength = 120;
const postContentMaxLength = 20000;
const postTagMaxCount = 10;
const postTagMaxLength = 32;

// 单张图片上限，和媒体服务限制一致。
const _maxImageBytes = 10 * 1024 * 1024;

// 本地图片读不出来（文件被移走、权限变化等）时的原因；IO 异常原文不展示给用户。
const _unreadableImageReason = '无法读取所选图片，请重新选择';

/// 编辑器实例键：[session] 由页面在创建或切换 postId 时新建，
/// 保证草稿、上传缓存与幂等键不会跨页面实例复用。
typedef PostEditorKey = ({Object? postId, Object session});

/// 发帖/编辑草稿状态；标题与正文仍由页面输入框持有，提交时传入。
class PostEditorState {
  /// 新建模式立即可编辑；编辑模式在原帖加载成功后才可提交。
  final bool isInitialized;

  /// 上传或提交进行中，提交按钮应禁用。
  final bool isSubmitting;

  /// 编辑模式载入的原帖，页面据此一次性回填标题与正文。
  final GetPostResp? original;

  /// 编辑模式加载原帖失败的原因；页面提示后退出编辑器。
  final Object? loadError;

  /// 编辑时乐观并发控制使用的原帖版本。
  final int revision;

  /// 已添加的标签，按添加顺序提交。
  final List<String> tags;

  /// 已在服务端的图片 URL（编辑模式原有图片）。
  final List<String> networkImages;

  /// 本地选择、尚未上传的图片。
  final List<XFile> localImages;

  const PostEditorState({
    this.isInitialized = false,
    this.isSubmitting = false,
    this.original,
    this.loadError,
    this.revision = 0,
    this.tags = const [],
    this.networkImages = const [],
    this.localImages = const [],
  });

  /// 复制并覆盖字段；`original` 与 `loadError` 只会被设置、不会被清空。
  PostEditorState copyWith({
    bool? isInitialized,
    bool? isSubmitting,
    GetPostResp? original,
    Object? loadError,
    int? revision,
    List<String>? tags,
    List<String>? networkImages,
    List<XFile>? localImages,
  }) {
    return PostEditorState(
      isInitialized: isInitialized ?? this.isInitialized,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      original: original ?? this.original,
      loadError: loadError ?? this.loadError,
      revision: revision ?? this.revision,
      tags: tags ?? this.tags,
      networkImages: networkImages ?? this.networkImages,
      localImages: localImages ?? this.localImages,
    );
  }
}

/// 提交成功后的去向：新建回到信息流，编辑返回上一页。
enum PostPublishOutcome { created, updated }

/// 草稿未通过客户端校验；不会发出任何请求。
class PostDraftInvalidException implements Exception {
  final String message;
  const PostDraftInvalidException(this.message);

  @override
  String toString() => message;
}

/// 图片批量上传的事务化异常：任一张失败则整帖不提交，已选图片保留供重试。
class PostImageUploadException implements Exception {
  /// 失败图片在本地选择列表中的序号（从 0 开始）。
  final int failedIndex;
  final String reason;
  const PostImageUploadException(this.failedIndex, this.reason);

  @override
  String toString() => '第 ${failedIndex + 1} 张图片上传失败：$reason';
}

/// 发帖与编辑的业务命令：载入原帖、维护标签与图片草稿、上传图片并提交。
///
/// 新建帖子的幂等键按完整命令指纹复用（FQ-006）：失败重试同一命令沿用原键，
/// 任一输入变化才换新键，成功后清除；图片按选择指纹缓存上传结果，重试不重复上传。
class PostEditorController extends StateNotifier<PostEditorState> {
  final PostRepository _repository;

  /// 编辑的帖子 ID；为空表示新建。
  final Object? postId;

  // 新建帖子的幂等键与生成它时的命令指纹。
  String? _createIdempotencyKey;
  String? _createCommandFingerprint;
  // 上一次全部上传成功的本地图片选择指纹及其结果，用于重试时跳过重复上传。
  String? _uploadedSelectionFingerprint;
  List<UploadedImage>? _uploadedLocalImages;

  PostEditorController({required PostRepository repository, this.postId})
    : _repository = repository,
      super(PostEditorState(isInitialized: postId == null)) {
    if (postId != null) _loadExistingPost(postId!);
  }

  /// 是否为编辑已有帖子。
  bool get isEditMode => postId != null;

  // 编辑模式先读原帖：回填草稿并记录版本，失败交给页面提示并退出。
  Future<void> _loadExistingPost(Object postId) async {
    try {
      final post = await _repository.getPostDetail(postId);
      if (!mounted) return;
      state = state.copyWith(
        original: post,
        tags: [...state.tags, ...post.tags],
        networkImages: [...state.networkImages, ...post.images],
        revision: post.revision.toInt(),
        isInitialized: true,
      );
    } catch (error) {
      if (mounted) state = state.copyWith(loadError: error);
    }
  }

  /// 添加标签；空白、超长、超数量或重复时忽略并返回 false，页面据此决定是否清空输入。
  bool addTag(String raw) {
    final tag = raw.trim();
    if (tag.isEmpty ||
        tag.length > postTagMaxLength ||
        state.tags.length >= postTagMaxCount ||
        state.tags.contains(tag)) {
      return false;
    }
    state = state.copyWith(tags: [...state.tags, tag]);
    return true;
  }

  /// 移除第 [index] 个标签。
  void removeTag(int index) {
    state = state.copyWith(tags: [...state.tags]..removeAt(index));
  }

  /// 追加一张本地选择的图片，提交时才上传。
  void addLocalImage(XFile file) {
    state = state.copyWith(localImages: [...state.localImages, file]);
  }

  /// 移除第 [index] 张尚未上传的本地图片。
  void removeLocalImage(int index) {
    state = state.copyWith(
      localImages: [...state.localImages]..removeAt(index),
    );
  }

  /// 移除第 [index] 张原帖已有图片；提交时不再带上它。
  void removeNetworkImage(int index) {
    state = state.copyWith(
      networkImages: [...state.networkImages]..removeAt(index),
    );
  }

  /// 上传本地图片并提交帖子；[status] 1 为发布、0 为草稿。
  ///
  /// 返回 null 表示命令被忽略（未就绪、提交中）或编辑器已被替换；此时页面不应导航或提示。
  /// 校验失败抛 [PostDraftInvalidException]，上传失败抛 [PostImageUploadException]，
  /// 其余网关错误原样抛出。
  Future<PostPublishOutcome?> publish({
    required String title,
    required String content,
    int status = 1,
  }) async {
    if (state.isSubmitting || !state.isInitialized) return null;
    // 先固定本次命令的全部输入，异步期间的草稿编辑不影响已发出的请求。
    final postId = this.postId;
    final revision = state.revision;
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();
    final tags = List<String>.of(state.tags);
    final networkImages = List<String>.of(state.networkImages);
    final localImages = List<XFile>.of(state.localImages);
    // 客户端校验与后端长度约束一致，不合法直接抛出、不发请求。
    if (trimmedTitle.isEmpty || trimmedTitle.length > postTitleMaxLength) {
      throw const PostDraftInvalidException('标题需为 1～$postTitleMaxLength 个字符');
    }
    if (trimmedContent.isEmpty ||
        trimmedContent.length > postContentMaxLength) {
      throw const PostDraftInvalidException('正文需为 1～$postContentMaxLength 个字符');
    }
    state = state.copyWith(isSubmitting: true);
    try {
      // 先上传全部本地图片，再与原有图片按「原图在前、新图在后」组装。
      final uploaded = await _uploadLocalImages(localImages);
      if (!mounted) return null;
      final allImages = [...networkImages, ...uploaded.map((item) => item.url)];
      final mediaIds = [
        ...uploaded.map((item) => item.mediaId).where(jsonInt64IsPositive),
      ];

      // 编辑：带原帖版本做乐观并发控制，冲突由页面提示刷新。
      if (postId != null) {
        if (revision <= 0) {
          throw const ApiException('缺少帖子版本，请刷新后重试');
        }
        await _repository.updateExistingPost(
          postId,
          UpdatePostV2Req(
            postId: postId,
            title: trimmedTitle,
            content: trimmedContent,
            images: allImages,
            tags: tags,
            status: status,
            expectedRevision: revision,
            mediaIds: mediaIds,
          ),
        );
        return mounted ? PostPublishOutcome.updated : null;
      }

      // 新建：同一完整命令的重试复用幂等键，任何输入变化换新键（FQ-006）。
      final commandFingerprint = jsonEncode({
        'title': trimmedTitle,
        'content': trimmedContent,
        'images': allImages,
        'tags': tags,
        'status': status,
        'mediaIds': mediaIds.map(jsonInt64Id).toList(growable: false),
      });
      if (_createIdempotencyKey == null ||
          _createCommandFingerprint != commandFingerprint) {
        _createIdempotencyKey = newIdempotencyKey();
        _createCommandFingerprint = commandFingerprint;
      }
      await _repository.createNewPost(
        CreatePostReq(
          title: trimmedTitle,
          content: trimmedContent,
          images: allImages,
          tags: tags,
          status: status,
          idempotencyKey: _createIdempotencyKey!,
          mediaIds: mediaIds,
        ),
      );
      if (!mounted) return null;
      // 成功后作废键，下一次发帖是新的命令。
      _createIdempotencyKey = null;
      _createCommandFingerprint = null;
      return PostPublishOutcome.created;
    } catch (_) {
      // 已被替换的编辑器不再向页面报告迟到的失败。
      if (!mounted) return null;
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isSubmitting: false);
    }
  }

  // 并发上传全部本地图片；同一选择的重试复用上次成功结果，任一失败则整体失败。
  Future<List<UploadedImage>> _uploadLocalImages(
    List<XFile> localImages,
  ) async {
    if (localImages.isEmpty) {
      _uploadedSelectionFingerprint = null;
      _uploadedLocalImages = null;
      return const [];
    }

    // 以路径、文件名与大小识别同一组选择，命中缓存则跳过重复上传；
    // 取不到大小说明文件已不可读，直接按该图片失败处理。
    final fingerprintParts = <Map<String, Object>>[];
    for (var i = 0; i < localImages.length; i++) {
      final file = localImages[i];
      final int length;
      try {
        length = await file.length();
      } catch (_) {
        throw PostImageUploadException(i, _unreadableImageReason);
      }
      fingerprintParts.add({
        'path': file.path,
        'name': file.name,
        'length': length,
      });
    }
    final selectionFingerprint = jsonEncode(fingerprintParts);
    if (!mounted) return const [];
    if (_uploadedSelectionFingerprint == selectionFingerprint &&
        _uploadedLocalImages != null) {
      return _uploadedLocalImages!;
    }

    // 每张图片独立校验与上传，结果带原始序号以便按选择顺序组装。
    final futures = <Future<(int, UploadedImage?, String?)>>[];
    for (var i = 0; i < localImages.length; i++) {
      final idx = i;
      final file = localImages[i];
      futures.add(() async {
        // 读取本地内容单独兜底，避免把 IO 异常原文当作失败原因展示。
        final Uint8List bytes;
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          return (idx, null, _unreadableImageReason);
        }
        try {
          final name = file.name;
          // 识别不出 jpeg/png/webp 的文件在上传前拒绝。
          if (detectImageMime(name, bytes) == null) {
            return (idx, null, '仅支持 JPEG、PNG 或 WebP');
          }
          if (bytes.length > _maxImageBytes) {
            return (idx, null, '单张图片不能超过 10 MiB');
          }
          final uploaded = await _repository.uploadImageMultipart(
            bytes: bytes,
            filename: name,
          );
          return (idx, uploaded, null);
        } catch (e) {
          // 上传失败已在 API 边界转成中文，这里统一取可展示文案。
          return (idx, null, friendlyErrorMessage(e));
        }
      }());
    }

    final results = await Future.wait(futures);

    // 报告序号最小的失败，提示与用户看到的图片顺序一致。
    results.sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in results) {
      if (r.$2 == null) {
        throw PostImageUploadException(r.$1, r.$3 ?? '上传失败');
      }
    }

    final uploaded = [for (final r in results) r.$2!];
    if (mounted) {
      _uploadedSelectionFingerprint = selectionFingerprint;
      _uploadedLocalImages = uploaded;
    }
    return uploaded;
  }
}

/// 每个编辑器页面实例一个 controller；页面离开或切换 postId 后自动释放，迟到结果随之失效。
final postEditorControllerProvider = StateNotifierProvider.autoDispose
    .family<PostEditorController, PostEditorState, PostEditorKey>((ref, key) {
      return PostEditorController(
        repository: ref.read(postRepositoryProvider),
        postId: key.postId,
      );
    });
