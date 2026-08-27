import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/api/idempotency.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../sdk/data/gateway.dart';
import '../data/post_repository.dart';
import 'widgets/image_picker_grid.dart';

const _maxTitleLength = 120;
const _maxContentLength = 20000;
const _maxTagCount = 10;
const _maxTagLength = 32;
const _maxImageBytes = 10 * 1024 * 1024;
const _allowedImageTypes = {'image/jpeg', 'image/png', 'image/webp'};

final _postRepoProvider = Provider((ref) => PostRepository());

class PostEditorPage extends ConsumerStatefulWidget {
  final Object? postId;
  const PostEditorPage({super.key, this.postId});

  @override
  ConsumerState<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends ConsumerState<PostEditorPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final List<String> _tags = [];
  final _tagCtrl = TextEditingController();
  final List<String> _networkImages = [];
  final List<Object> _networkMediaIds = [];
  final List<XFile> _localImages = [];
  int _revision = 0;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _createIdempotencyKey;
  String? _createCommandFingerprint;
  String? _uploadedSelectionFingerprint;
  List<UploadedImage>? _uploadedLocalImages;

  bool get _isEditMode => widget.postId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingPost();
    } else {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingPost() async {
    try {
      final post = await ref
          .read(_postRepoProvider)
          .getPostDetail(widget.postId!);
      setState(() {
        _titleCtrl.text = post.title;
        _contentCtrl.text = post.content;
        _tags.addAll(post.tags);
        _networkImages.addAll(post.images);
        _revision = post.revision.toInt();
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        showAppError(context, '加载失败: ${friendlyErrorMessage(e)}');
        context.pop();
      }
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty ||
        tag.length > _maxTagLength ||
        _tags.length >= _maxTagCount ||
        _tags.contains(tag)) {
      return;
    }
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  Future<List<UploadedImage>> _uploadLocalImages() async {
    if (_localImages.isEmpty) {
      _uploadedSelectionFingerprint = null;
      _uploadedLocalImages = null;
      return const [];
    }

    final selectionFingerprint = jsonEncode([
      for (final file in _localImages)
        {'path': file.path, 'name': file.name, 'length': await file.length()},
    ]);
    if (_uploadedSelectionFingerprint == selectionFingerprint &&
        _uploadedLocalImages != null) {
      return _uploadedLocalImages!;
    }

    final repo = ref.read(_postRepoProvider);

    final futures = <Future<(int, UploadedImage?, String?)>>[];
    for (var i = 0; i < _localImages.length; i++) {
      final idx = i;
      final file = _localImages[i];
      futures.add(() async {
        try {
          final bytes = await file.readAsBytes();
          final name = file.name;
          final mime = _inferLocalImageMime(name, bytes);
          if (!_allowedImageTypes.contains(mime)) {
            return (idx, null, '仅支持 JPEG、PNG 或 WebP');
          }
          if (bytes.length > _maxImageBytes) {
            return (idx, null, '单张图片不能超过 10 MiB');
          }
          final uploaded = await repo.uploadImageMultipart(
            bytes: bytes,
            filename: name,
          );
          return (idx, uploaded, null);
        } catch (e) {
          return (idx, null, e.toString());
        }
      }());
    }

    final results = await Future.wait(futures);

    results.sort((a, b) => a.$1.compareTo(b.$1));
    for (final r in results) {
      if (r.$2 == null) {
        throw _UploadTransactionException(r.$1, r.$3 ?? 'unknown');
      }
    }

    final uploaded = [for (final r in results) r.$2!];
    _uploadedSelectionFingerprint = selectionFingerprint;
    _uploadedLocalImages = uploaded;
    return uploaded;
  }

  Future<void> _publish({int status = 1}) async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty || title.length > _maxTitleLength) {
      showAppError(context, '标题需为 1～$_maxTitleLength 个字符');
      return;
    }
    if (content.isEmpty || content.length > _maxContentLength) {
      showAppError(context, '正文需为 1～$_maxContentLength 个字符');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uploaded = await _uploadLocalImages();
      final allImages = [
        ..._networkImages,
        ...uploaded.map((item) => item.url),
      ];
      final mediaIds = [
        ..._networkMediaIds.where(jsonInt64IsPositive),
        ...uploaded.map((item) => item.mediaId).where(jsonInt64IsPositive),
      ];

      if (_isEditMode) {
        if (_revision <= 0) {
          throw const ApiException('缺少帖子版本，请刷新后重试');
        }
        await ref
            .read(_postRepoProvider)
            .updateExistingPost(
              widget.postId!,
              UpdatePostV2Req(
                postId: widget.postId!,
                title: title,
                content: content,
                images: allImages,
                tags: _tags,
                status: status,
                expectedRevision: _revision,
                mediaIds: mediaIds,
              ),
            );
        if (mounted) context.pop();
      } else {
        final commandFingerprint = jsonEncode({
          'title': title,
          'content': content,
          'images': allImages,
          'tags': _tags,
          'status': status,
          'mediaIds': mediaIds.map(jsonInt64Id).toList(growable: false),
        });
        if (_createIdempotencyKey == null ||
            _createCommandFingerprint != commandFingerprint) {
          _createIdempotencyKey = newIdempotencyKey();
          _createCommandFingerprint = commandFingerprint;
        }
        await ref
            .read(_postRepoProvider)
            .createNewPost(
              CreatePostReq(
                title: title,
                content: content,
                images: allImages,
                tags: _tags,
                status: status,
                idempotencyKey: _createIdempotencyKey!,
                mediaIds: mediaIds,
              ),
            );
        _createIdempotencyKey = null;
        _createCommandFingerprint = null;
        if (mounted) {
          context.go('/feed');
        }
      }
    } on _UploadTransactionException catch (e) {
      if (mounted) {
        await showAppAlert(
          context: context,
          title: '图片上传失败',
          message: '${e.toString()}\n\n帖子未发布，图片已保留，可修改后重试。',
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        showAppError(
          context,
          e.code == ErrorCodes.contentVersionConflict
              ? '内容已被更新，请刷新后再提交'
              : '发布失败: ${friendlyErrorMessage(e)}',
        );
      }
    } catch (e) {
      if (mounted) {
        showAppError(context, '发布失败: ${friendlyErrorMessage(e)}');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(_isEditMode ? '编辑帖子' : '发布帖子'),
        prefixes: [
          FHeaderAction.back(
            onPress: () =>
                context.canPop() ? context.pop() : context.go('/feed'),
          ),
        ],
        suffixes: [
          if (!_isEditMode)
            FButton(
              variant: .ghost,
              size: .sm,
              mainAxisSize: MainAxisSize.min,
              onPress: _isLoading ? null : () => _publish(status: 0),
              child: const Text('存草稿'),
            ),
          FButton(
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: _isLoading ? null : () => _publish(),
            child: _isLoading
                ? const FCircularProgress(size: .sm)
                : const Text('发布'),
          ),
        ],
      ),
      child: !_isInitialized
          ? const Center(child: FCircularProgress())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                FTextField(
                  control: FTextFieldControl.managed(controller: _titleCtrl),
                  label: const Text('标题'),
                  hint: '请输入标题（最多$_maxTitleLength字）',
                  maxLength: _maxTitleLength,
                ),
                const SizedBox(height: 16),
                FTextField.multiline(
                  control: FTextFieldControl.managed(controller: _contentCtrl),
                  label: const Text('内容'),
                  hint: '分享你的想法...',
                  minLines: 8,
                  maxLines: 8,
                  maxLength: _maxContentLength,
                ),
                const SizedBox(height: 16),
                // 标签
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FTextField(
                        control: FTextFieldControl.managed(
                          controller: _tagCtrl,
                        ),
                        label: const Text('添加标签'),
                        hint: '输入标签后点击添加',
                        onSubmit: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FButton.icon(
                      onPress: _addTag,
                      semanticsLabel: '添加标签',
                      child: const Icon(FLucideIcons.plus),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: _tags
                        .asMap()
                        .entries
                        .map(
                          (e) => AppTagBadge(
                            label: e.value,
                            onRemove: () =>
                                setState(() => _tags.removeAt(e.key)),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Text('图片', style: theme.typography.body.md),
                const SizedBox(height: 8),
                ImagePickerGrid(
                  networkImages: _networkImages,
                  localImages: _localImages,
                  onAdd: (file) => setState(() => _localImages.add(file)),
                  onRemoveNetwork: (i) =>
                      setState(() => _networkImages.removeAt(i)),
                  onRemoveLocal: (i) =>
                      setState(() => _localImages.removeAt(i)),
                ),
              ],
            ),
    );
  }
}

String _inferLocalImageMime(String filename, List<int> bytes) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return 'image/jpeg';
  }
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return 'image/png';
  }
  return 'application/octet-stream';
}

/// 图片批量上传的事务化异常
class _UploadTransactionException implements Exception {
  final int failedIndex;
  final String reason;
  const _UploadTransactionException(this.failedIndex, this.reason);

  @override
  String toString() => '第 ${failedIndex + 1} 张图片上传失败：$reason';
}
