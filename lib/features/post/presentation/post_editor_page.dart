import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../sdk/data/gateway.dart';
import '../data/post_repository.dart';
import 'widgets/image_picker_grid.dart';

final _postRepoProvider = Provider((ref) => PostRepository());

class PostEditorPage extends ConsumerStatefulWidget {
  final int? postId;
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
  final List<File> _localImages = [];
  bool _isLoading = false;
  bool _isInitialized = false;

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
      final post =
          await ref.read(_postRepoProvider).getPostDetail(widget.postId!);
      setState(() {
        _titleCtrl.text = post.title;
        _contentCtrl.text = post.content;
        _tags.addAll(post.tags);
        _networkImages.addAll(post.images);
        _isInitialized = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('加载失败: ${friendlyErrorMessage(e)}')));
        context.pop();
      }
    }
  }

  void _addTag() {
    final tag = _tagCtrl.text.trim();
    if (tag.isEmpty || _tags.length >= 5 || _tags.contains(tag)) return;
    setState(() => _tags.add(tag));
    _tagCtrl.clear();
  }

  Future<List<String>> _uploadLocalImages() async {
    if (_localImages.isEmpty) return const [];

    final repo = ref.read(_postRepoProvider);

    final futures = <Future<(int, String?, String?)>>[];
    for (var i = 0; i < _localImages.length; i++) {
      final idx = i;
      final file = _localImages[i];
      futures.add(() async {
        try {
          final bytes = await file.readAsBytes();
          final name = file.path.split(RegExp(r'[/\\]')).last;
          final url = await repo.uploadImageMultipart(
            bytes: bytes,
            filename: name,
          );
          return (idx, url, null);
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

    return [for (final r in results) r.$2!];
  }

  Future<void> _publish({int status = 1}) async {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final uploadedUrls = await _uploadLocalImages();
      final allImages = [..._networkImages, ...uploadedUrls];

      if (_isEditMode) {
        await ref.read(_postRepoProvider).updateExistingPost(
              widget.postId!,
              UpdatePostReq(
                postId: widget.postId!,
                title: _titleCtrl.text.trim(),
                content: _contentCtrl.text.trim(),
                images: allImages,
                tags: _tags,
              ),
            );
        if (mounted) context.pop();
      } else {
        final resp = await ref.read(_postRepoProvider).createNewPost(
              CreatePostReq(
                title: _titleCtrl.text.trim(),
                content: _contentCtrl.text.trim(),
                images: allImages,
                tags: _tags,
                status: status,
              ),
            );
        if (mounted) {
          context.go('/post/${resp.postId.toInt()}');
        }
      }
    } on _UploadTransactionException catch (e) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('图片上传失败'),
            content: Text(
              '${e.toString()}\n\n帖子未发布，图片已保留，可修改后重试。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('发布失败: ${friendlyErrorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? '编辑帖子' : '发布帖子'),
        actions: [
          if (!_isEditMode)
            TextButton(
              onPressed: _isLoading ? null : () => _publish(status: 0),
              child: const Text('存草稿'),
            ),
          TextButton(
            onPressed: _isLoading ? null : () => _publish(),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('发布'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: !_isInitialized
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: '标题',
                    hintText: '请输入标题（最多100字）',
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _contentCtrl,
                  decoration: const InputDecoration(
                    labelText: '内容',
                    hintText: '分享你的想法...',
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  maxLength: 10000,
                ),
                const SizedBox(height: 16),
                // 标签
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagCtrl,
                        decoration: const InputDecoration(
                          labelText: '添加标签',
                          hintText: '输入标签后点击添加',
                          isDense: true,
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add_circle_outline),
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
                        .map((e) => Chip(
                              label: Text(e.value),
                              onDeleted: () =>
                                  setState(() => _tags.removeAt(e.key)),
                            ))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Text('图片', style: Theme.of(context).textTheme.titleSmall),
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

/// 图片批量上传的事务化异常
class _UploadTransactionException implements Exception {
  final int failedIndex;
  final String reason;
  const _UploadTransactionException(this.failedIndex, this.reason);

  @override
  String toString() => '第 ${failedIndex + 1} 张图片上传失败：$reason';
}
