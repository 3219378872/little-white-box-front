import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/error_codes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_tag_badge.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/loading_view.dart';
import '../application/post_editor_controller.dart';
import 'widgets/image_picker_grid.dart';

/// 发帖与编辑页：持有标题/正文输入框，草稿、上传与提交命令交给 [PostEditorController]。
class PostEditorPage extends ConsumerStatefulWidget {
  final Object? postId;
  const PostEditorPage({super.key, this.postId});

  @override
  ConsumerState<PostEditorPage> createState() => _PostEditorPageState();
}

class _PostEditorPageState extends ConsumerState<PostEditorPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();

  // 每个页面实例（及每次切换 postId）独占一个 controller，旧编辑器的迟到结果随之失效。
  Object _session = Object();

  bool get _isEditMode => widget.postId != null;

  PostEditorKey get _editorKey => (postId: widget.postId, session: _session);

  @override
  void didUpdateWidget(covariant PostEditorPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId == widget.postId) return;
    // 切换到另一篇帖子：清空输入并换新 controller，重新加载目标帖子。
    _session = Object();
    _titleCtrl.clear();
    _contentCtrl.clear();
    _tagCtrl.clear();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  // 原帖载入后一次性回填输入框；载入失败提示并退出编辑器。
  void _onEditorChanged(PostEditorState? previous, PostEditorState next) {
    if (previous?.original == null && next.original != null) {
      _titleCtrl.text = next.original!.title;
      _contentCtrl.text = next.original!.content;
    }
    if (previous?.loadError == null && next.loadError != null) {
      showAppError(context, '加载失败: ${friendlyErrorMessage(next.loadError!)}');
      context.pop();
    }
  }

  void _addTag() {
    final added = ref
        .read(postEditorControllerProvider(_editorKey).notifier)
        .addTag(_tagCtrl.text);
    if (added) _tagCtrl.clear();
  }

  // 提交并按结果导航；各类失败在此转成提示，旧编辑器的结果由 controller 返回 null 屏蔽。
  Future<void> _publish({int status = 1}) async {
    final controller = ref.read(
      postEditorControllerProvider(_editorKey).notifier,
    );
    try {
      final outcome = await controller.publish(
        title: _titleCtrl.text,
        content: _contentCtrl.text,
        status: status,
      );
      if (outcome == null || !mounted) return;
      switch (outcome) {
        case PostPublishOutcome.updated:
          context.pop();
        case PostPublishOutcome.created:
          context.go('/feed');
      }
    } on PostDraftInvalidException catch (e) {
      if (mounted) showAppError(context, e.message);
    } on PostImageUploadException catch (e) {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final key = _editorKey;
    final editor = ref.watch(postEditorControllerProvider(key));
    final controller = ref.read(postEditorControllerProvider(key).notifier);
    ref.listen(postEditorControllerProvider(key), _onEditorChanged);
    final canSubmit = !editor.isSubmitting && editor.isInitialized;
    return FScaffold(
      childPad: false,
      header: FHeader.nested(
        title: Text(_isEditMode ? '编辑帖子' : '发帖'),
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
              onPress: canSubmit ? () => _publish(status: 0) : null,
              child: const Text('存草稿'),
            ),
          FButton(
            size: .sm,
            mainAxisSize: MainAxisSize.min,
            onPress: canSubmit ? () => _publish() : null,
            child: editor.isSubmitting
                ? const FCircularProgress(size: .sm)
                : const Text('发布'),
          ),
        ],
      ),
      child: !editor.isInitialized
          ? const LoadingView()
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              children: [
                Semantics(
                  label: '帖子标题',
                  child: FTextField.multiline(
                    control: FTextFieldControl.managed(controller: _titleCtrl),
                    style: AppTheme.editorField(context, title: true),
                    hint: '标题',
                    minLines: 1,
                    maxLines: 3,
                    maxLength: postTitleMaxLength,
                  ),
                ),
                const FDivider(),
                Semantics(
                  label: '正文',
                  child: FTextField.multiline(
                    control: FTextFieldControl.managed(
                      controller: _contentCtrl,
                    ),
                    style: AppTheme.editorField(context),
                    hint: '分享你的想法...',
                    minLines: 8,
                    maxLines: 20,
                    maxLength: postContentMaxLength,
                  ),
                ),
                const SizedBox(height: 16),
                // 标签
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Semantics(
                        label: '帖子标签',
                        child: FTextField(
                          control: FTextFieldControl.managed(
                            controller: _tagCtrl,
                          ),
                          hint: '标签',
                          maxLength: postTagMaxLength,
                          onSubmit: (_) => _addTag(),
                        ),
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
                if (editor.tags.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: editor.tags
                        .asMap()
                        .entries
                        .map(
                          (e) => AppTagBadge(
                            label: e.value,
                            onRemove: () => controller.removeTag(e.key),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      FLucideIcons.images,
                      size: 18,
                      color: theme.colors.mutedForeground,
                    ),
                    const SizedBox(width: 8),
                    Text('图片', style: theme.typography.body.sm),
                    const Spacer(),
                    Text(
                      '${editor.networkImages.length + editor.localImages.length}/9',
                      style: theme.typography.body.xs.copyWith(
                        color: theme.colors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ImagePickerGrid(
                  networkImages: editor.networkImages,
                  localImages: editor.localImages,
                  onAdd: controller.addLocalImage,
                  onRemoveNetwork: controller.removeNetworkImage,
                  onRemoveLocal: controller.removeLocalImage,
                ),
              ],
            ),
    );
  }
}
