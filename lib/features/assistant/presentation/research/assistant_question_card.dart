import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/assistant_models.dart';

/// 提交澄清回答的回调；`continueExpired` 表示在过期或停止后继续作答，返回是否被接受。
typedef AnswerQuestion = Future<bool> Function(
  AssistantQuestionRequest question,
  List<AssistantQuestionAnswer> answers,
  bool continueExpired,
);

/// Agent 发起的澄清问题卡片：待答时可选择或补充说明，已答或已转向后默认收起为摘要。
class AssistantQuestionCard extends StatefulWidget {
  final AssistantQuestionRequest question;
  final AnswerQuestion onAnswer;
  const AssistantQuestionCard({
    super.key,
    required this.question,
    required this.onAnswer,
  });
  @override
  State<AssistantQuestionCard> createState() => _AssistantQuestionCardState();
}

// 持有每道题的本地草稿（选项、处置、补充说明），并在截止时间到达时刷新可编辑状态。
class _AssistantQuestionCardState extends State<AssistantQuestionCard> {
  final _selected = <String, Set<String>>{};
  final _dispositions = <String, String>{};
  final _text = <String, TextEditingController>{};
  Timer? _timer;
  bool _busy = false;
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _collapsed =
        widget.question.status == 'answered' ||
        widget.question.status == 'superseded';
    _initialize();
  }

  // 用服务端已提交的答案回填草稿，并每秒检查一次是否过期以切换按钮文案。
  void _initialize() {
    for (final question in widget.question.questions) {
      final answer = widget.question.answers
          .where((answer) => answer.questionId == question.id)
          .firstOrNull;
      _selected[question.id] = {...?answer?.selectedOptionIds};
      _dispositions[question.id] = answer?.disposition ?? '';
      _text[question.id] = TextEditingController(text: answer?.text ?? '');
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.question.isPending || widget.question.hasExpired) {
        _timer?.cancel();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(AssistantQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.status != widget.question.status) {
      _collapsed =
          widget.question.status == 'answered' ||
          widget.question.status == 'superseded';
    }
    // 换题或服务端回写了答案时丢弃本地草稿，按新数据重建。
    if (oldWidget.question.id != widget.question.id ||
        (oldWidget.question.status != widget.question.status &&
            widget.question.answers.isNotEmpty)) {
      _timer?.cancel();
      for (final controller in _text.values) {
        controller.dispose();
      }
      _text.clear();
      _initialize();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // 过期或被停止的问题仍允许继续作答，提交时会带上 continueExpired。
  bool get _editable =>
      !_busy &&
      (widget.question.isPending ||
          widget.question.status == 'expired' ||
          widget.question.status == 'cancelled');

  // 由草稿组装答案；`skipUnanswered` 把未作答的题标为 skipped 以便直接搜索。
  List<AssistantQuestionAnswer> _answers({bool skipUnanswered = false}) => [
    for (final question in widget.question.questions)
      AssistantQuestionAnswer(
        questionId: question.id,
        selectedOptionIds: _selected[question.id]!.toList(),
        text: _text[question.id]!.text.trim(),
        disposition:
            (_dispositions[question.id]!.isEmpty ||
                    (_dispositions[question.id] == 'answered' &&
                        _selected[question.id]!.isEmpty &&
                        _text[question.id]!.text.trim().isEmpty)) &&
                skipUnanswered
            ? 'skipped'
            : _dispositions[question.id]!,
      ),
  ];

  // 每题都有处置且 answered 必须有选项或说明；补充说明合计不超过 2000 字。
  bool get _valid =>
      _answers().every(
        (answer) =>
            answer.disposition.isNotEmpty &&
            (answer.disposition != 'answered' ||
                answer.selectedOptionIds.isNotEmpty ||
                answer.text.isNotEmpty),
      ) &&
      _text.values.fold<int>(
            0,
            (total, controller) => total + controller.text.runes.length,
          ) <=
          2000;

  // 提交草稿；过期或已停止的问题以续答方式提交。
  Future<void> _submit(bool skip) async {
    if (!_editable) return;
    setState(() => _busy = true);
    await widget.onAnswer(
      widget.question,
      _answers(skipUnanswered: skip),
      widget.question.hasExpired || widget.question.status == 'cancelled',
    );
    if (mounted) setState(() => _busy = false);
  }

  // 选中选项即视为 answered；单选题先清空已选项。
  void _choose(String questionId, String option, bool selected, bool multiple) {
    setState(() {
      _dispositions[questionId] = 'answered';
      if (!multiple) _selected[questionId]!.clear();
      if (selected) {
        _selected[questionId]!.add(option);
      } else {
        _selected[questionId]!.remove(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final status = widget.question.hasExpired
        ? '已过期'
        : switch (widget.question.status) {
            'answered' => '已回答',
            'superseded' => '已转向',
            'cancelled' => '已停止',
            _ => '补充条件',
          };
    // 已答/已转向默认收起为摘要，可展开查看。
    if (_collapsed) {
      return _CollapsedQuestionCard(
        request: widget.question,
        status: status,
        onExpand: () => setState(() => _collapsed = false),
      );
    }
    return FCard(
      style: AppTheme.assistantCard,
      key: Key('assistant-question-${widget.question.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                if (!widget.question.isPending)
                  FTooltip(
                    tipBuilder: (_, _) => const Text('收起回答'),
                    child: FButton.icon(
                      variant: .ghost,
                      onPress: () => setState(() => _collapsed = true),
                      child: const Icon(
                        FLucideIcons.chevronUp,
                        semanticLabel: '收起回答',
                      ),
                    ),
                  ),
              ],
            ),
            // 每道题的编辑区。
            for (final question in widget.question.questions)
              _QuestionEditor(
                question: question,
                selected: _selected[question.id]!,
                disposition: _dispositions[question.id]!,
                controller: _text[question.id]!,
                editable: _editable,
                onOptionChanged: (optionId, value) => _choose(
                  question.id,
                  optionId,
                  question.selection == 'multiple' ? value : true,
                  question.selection == 'multiple',
                ),
                onDispositionChosen: (disposition) => setState(() {
                  _selected[question.id]!.clear();
                  _dispositions[question.id] = disposition;
                }),
                onTextChanged: () => setState(() {
                  if (_dispositions[question.id]!.isEmpty) {
                    _dispositions[question.id] = 'answered';
                  }
                }),
              ),
            // 可编辑或提交中时显示操作区。
            if (_editable || _busy)
              _QuestionActions(
                requestId: widget.question.id,
                valid: _valid,
                busy: _busy,
                continuing:
                    widget.question.hasExpired ||
                    widget.question.status == 'cancelled',
                onSubmit: () => _submit(false),
                onSkip: () => _submit(true),
              ),
          ],
        ),
      ),
    );
  }
}

// 收起态卡片：只展示状态与每题已提交答案的摘要，提供展开入口。
class _CollapsedQuestionCard extends StatelessWidget {
  final AssistantQuestionRequest request;
  final String status;
  final VoidCallback onExpand;

  const _CollapsedQuestionCard({
    required this.request,
    required this.status,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return FCard(
      style: AppTheme.assistantCard,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    status,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.mutedForeground,
                    ),
                  ),
                ),
                FTooltip(
                  tipBuilder: (_, _) => const Text('展开回答'),
                  child: FButton.icon(
                    key: Key('question-details-${request.id}'),
                    variant: .ghost,
                    onPress: onExpand,
                    child: const Icon(
                      FLucideIcons.chevronDown,
                      semanticLabel: '展开回答',
                    ),
                  ),
                ),
              ],
            ),
            for (final question in request.questions) ...[
              Text(
                question.text,
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _answerSummary(question),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.typography.body.sm,
              ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }

  // 把处置、所选选项与补充说明拼成一行可读摘要；未提交的题显示「未提交」。
  String _answerSummary(AssistantQuestion question) {
    final answer = request.answers
        .where((answer) => answer.questionId == question.id)
        .firstOrNull;
    if (answer == null) return '未提交';
    final values = <String>[];
    if (answer.disposition != 'answered') {
      values.add(
        const {
              'unknown': '不知道',
              'no_preference': '没有偏好',
              'skipped': '已跳过',
            }[answer.disposition] ??
            '答案不可用',
      );
    }
    for (final option in question.options) {
      if (answer.selectedOptionIds.contains(option.id)) {
        values.add(option.label);
      }
    }
    if (answer.text.isNotEmpty) values.add(answer.text);
    return values.join('；');
  }
}

// 单道题的编辑区：选项、互斥的「不知道/没有偏好」处置与补充说明；草稿由卡片状态持有。
class _QuestionEditor extends StatelessWidget {
  final AssistantQuestion question;
  final Set<String> selected;
  final String disposition;
  final TextEditingController controller;
  final bool editable;
  final void Function(String optionId, bool value) onOptionChanged;
  final ValueChanged<String> onDispositionChosen;
  final VoidCallback onTextChanged;

  const _QuestionEditor({
    required this.question,
    required this.selected,
    required this.disposition,
    required this.controller,
    required this.editable,
    required this.onOptionChanged,
    required this.onDispositionChosen,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          question.text,
          style: theme.typography.body.md.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          question.selection == 'multiple' ? '可多选' : '选择一项',
          style: theme.typography.body.xs.copyWith(
            color: theme.colors.mutedForeground,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in question.options)
              _ChoiceChip(
                key: Key('question-${question.id}-${option.id}'),
                label: option.label,
                multiple: question.selection == 'multiple',
                selected: selected.contains(option.id),
                enabled: editable,
                onChanged: (value) => onOptionChanged(option.id, value),
              ),
          ],
        ),
        const SizedBox(height: 8),
        // 「没有答案」类处置与选项分开展示，避免单选/多选语义混在一起。
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '或者',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
            for (final choice in const [
              ('unknown', '不知道'),
              ('no_preference', '没有偏好'),
            ])
              _ChoiceChip(
                key: Key('question-${question.id}-${choice.$1}'),
                label: choice.$2,
                multiple: false,
                subtle: true,
                selected: disposition == choice.$1,
                enabled: editable,
                onChanged: (_) => onDispositionChosen(choice.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        FTextField.multiline(
          control: FTextFieldControl.managed(
            controller: controller,
            onChange: (_) => onTextChanged(),
          ),
          enabled: editable,
          label: const Text('补充说明（可选）'),
          hint: '例如：预算 3000 以内、偏好开源方案',
          minLines: 1,
          maxLines: 3,
          maxLength: 2000,
        ),
      ],
    );
  }
}

// 卡片底部的提交区：未满足条件时给出提示，过期/停止后提交按钮改为「继续回答」。
class _QuestionActions extends StatelessWidget {
  final String requestId;
  final bool valid;
  final bool busy;
  final bool continuing;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;

  const _QuestionActions({
    required this.requestId,
    required this.valid,
    required this.busy,
    required this.continuing,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        if (!valid && !busy)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '选择一项或填写补充说明后即可提交',
              style: theme.typography.body.xs.copyWith(
                color: theme.colors.mutedForeground,
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: FButton(
                key: Key('question-submit-$requestId'),
                size: .sm,
                onPress: valid && !busy ? onSubmit : null,
                child: Text(
                  busy
                      ? '提交中'
                      : continuing
                      ? '继续回答'
                      : '提交回答',
                ),
              ),
            ),
            const SizedBox(width: 8),
            FButton(
              key: Key('question-search-$requestId'),
              size: .sm,
              variant: .ghost,
              mainAxisSize: MainAxisSize.min,
              onPress: busy ? null : onSkip,
              child: const Text('跳过，直接搜索'),
            ),
          ],
        ),
      ],
    );
  }
}

// 澄清问题使用的可选标签；按单选/多选暴露 radio 或 checkbox 语义，便于读屏播报选择模型。
class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool multiple;
  final bool enabled;
  final bool subtle;
  final ValueChanged<bool> onChanged;

  const _ChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.multiple,
    required this.enabled,
    required this.onChanged,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colors = theme.colors;
    final foreground = !enabled
        ? colors.disable(colors.foreground)
        : selected
        ? colors.primary
        : subtle
        ? colors.secondaryForeground
        : colors.foreground;
    return FTappable(
      onPress: enabled ? () => onChanged(!selected) : null,
      semanticsLabel: label,
      semanticsButton: false,
      semanticsChecked: selected,
      semanticsInMutuallyExclusiveGroup: multiple ? null : true,
      excludeSemantics: true,
      builder: (context, variants, _) {
        final hovered =
            enabled &&
            (variants.contains(FTappableVariant.hovered) ||
                variants.contains(FTappableVariant.pressed));
        return AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accentSoft(colors)
                : hovered
                ? colors.secondary
                : subtle
                ? colors.background
                : colors.muted,
            borderRadius: AppTheme.controlRadius,
            border: Border.all(
              color: selected ? colors.primary : colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(FLucideIcons.check, size: 14, color: foreground),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: theme.typography.body.sm.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
