import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api/api_adapter.dart';
import '../../../sdk/api/gateway.dart' as gw;
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
            .showSnackBar(SnackBar(content: Text('加载失败: $e')));
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
    final urls = <String>[];
    for (final file in _localImages) {
      final bytes = await file.readAsBytes();
      final resp = await apiCall<UploadImageResp>(
        (ok, fail, eventually) => gw.uploadImage(
          UploadImageReq(file: bytes.toList()),
          ok: ok,
          fail: fail,
          eventually: eventually,
        ),
      );
      urls.add(resp.url);
    }
    return urls;
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('发布失败: $e')));
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
          FilledButton(
            onPressed: _isLoading ? null : () => _publish(),
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
