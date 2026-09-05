import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/json_int64.dart';
import '../../../core/theme/app_theme.dart';
import '../../../sdk/vars/vars.dart';
import '../data/assistant_models.dart';

typedef AnswerQuestion =
    Future<bool> Function(
      AssistantQuestionRequest question,
      List<AssistantQuestionAnswer> answers,
      bool continueExpired,
    );

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

  bool get _editable =>
      !_busy &&
      (widget.question.isPending ||
          widget.question.status == 'expired' ||
          widget.question.status == 'cancelled');
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
    if (_collapsed) {
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
                      key: Key('question-details-${widget.question.id}'),
                      variant: .ghost,
                      onPress: () => setState(() => _collapsed = false),
                      child: const Icon(
                        FLucideIcons.chevronDown,
                        semanticLabel: '展开回答',
                      ),
                    ),
                  ),
                ],
              ),
              for (final question in widget.question.questions) ...[
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
            for (final question in widget.question.questions) ...[
              const SizedBox(height: 12),
              Text(question.text, style: theme.typography.body.md),
              const SizedBox(height: 8),
              for (final option in question.options)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: question.selection == 'multiple'
                      ? FCheckbox(
                          key: Key('question-${question.id}-${option.id}'),
                          label: Text(option.label),
                          semanticsLabel: option.label,
                          value: _selected[question.id]!.contains(option.id),
                          enabled: _editable,
                          onChange: (value) =>
                              _choose(question.id, option.id, value, true),
                        )
                      : FRadio(
                          key: Key('question-${question.id}-${option.id}'),
                          label: Text(option.label),
                          semanticsLabel: option.label,
                          value: _selected[question.id]!.contains(option.id),
                          enabled: _editable,
                          onChange: (value) =>
                              _choose(question.id, option.id, true, false),
                        ),
                ),
              for (final choice in const [
                ('unknown', '不知道'),
                ('no_preference', '没有偏好'),
                ('skipped', '跳过'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FRadio(
                    key: Key('question-${question.id}-${choice.$1}'),
                    label: Text(choice.$2),
                    semanticsLabel: choice.$2,
                    value: _dispositions[question.id] == choice.$1,
                    enabled: _editable,
                    onChange: (_) => setState(() {
                      _selected[question.id]!.clear();
                      _dispositions[question.id] = choice.$1;
                    }),
                  ),
                ),
              const SizedBox(height: 6),
              FTextField.multiline(
                control: FTextFieldControl.managed(
                  controller: _text[question.id],
                  onChange: (_) => setState(() {
                    if (_dispositions[question.id]!.isEmpty) {
                      _dispositions[question.id] = 'answered';
                    }
                  }),
                ),
                enabled: _editable,
                label: const Text('补充'),
                minLines: 1,
                maxLines: 3,
                maxLength: 2000,
              ),
            ],
            if (_editable || _busy) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FButton(
                    key: Key('question-submit-${widget.question.id}'),
                    size: .sm,
                    onPress: _valid && !_busy ? () => _submit(false) : null,
                    child: Text(
                      _busy
                          ? '提交中'
                          : widget.question.hasExpired ||
                                widget.question.status == 'cancelled'
                          ? '继续回答'
                          : '提交回答',
                    ),
                  ),
                  FButton(
                    key: Key('question-search-${widget.question.id}'),
                    size: .sm,
                    variant: .secondary,
                    onPress: _busy ? null : () => _submit(true),
                    child: const Text('先搜索'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _answerSummary(AssistantQuestion question) {
    final answer = widget.question.answers
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

class AssistantResearchAnswer extends StatefulWidget {
  final AssistantAnswerPresentation answer;
  final ValueChanged<AssistantSourceCard>? onDislike;
  final Future<bool> Function(Uri)? openExternal;
  const AssistantResearchAnswer({
    super.key,
    required this.answer,
    this.onDislike,
    this.openExternal,
  });
  @override
  State<AssistantResearchAnswer> createState() =>
      _AssistantResearchAnswerState();
}

class _AssistantResearchAnswerState extends State<AssistantResearchAnswer> {
  final _keys = <String, GlobalKey>{};
  String? _highlighted;
  Future<void> _reveal(String handle) async {
    setState(() => _highlighted = handle);
    final context = _keys[handle]?.currentContext;
    if (context != null) {
      await Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sources = widget.answer.sources;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final block in widget.answer.blocks) ...[
          if (block.kind == 'inference' || block.kind == 'experience')
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                block.kind == 'inference' ? '综合判断' : '个人体验',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            ),
          GptMarkdown(
            block.text,
            style: theme.typography.body.md,
            onLinkTap: (_, _) {},
            imageBuilder: (_, _, _, _) => const SizedBox.shrink(),
          ),
          if (block.citations.isNotEmpty)
            Wrap(
              spacing: 2,
              children: [
                for (final handle
                    in block.citations
                        .map((citation) => citation.handle)
                        .toSet())
                  IntrinsicWidth(
                    child: FButton(
                      key: Key('citation-${block.id}-$handle'),
                      variant: .ghost,
                      size: .sm,
                      onPress: () => _reveal(handle),
                      child: Text(
                        '[${sources.indexWhere((source) => source.handle == handle) + 1}]${sources.any((source) => source.handle == handle && !source.available) ? ' 来源失效' : ''}',
                      ),
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 12),
        ],
        for (var i = 0; i < sources.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AssistantResearchSourceCard(
              key: _keys.putIfAbsent(sources[i].handle, () => GlobalKey()),
              source: sources[i],
              index: i + 1,
              highlighted: _highlighted == sources[i].handle,
              onDislike: widget.onDislike,
              openExternal: widget.openExternal,
            ),
          ),
      ],
    );
  }
}

class AssistantResearchSourceCard extends StatefulWidget {
  final AssistantResearchSource source;
  final int index;
  final bool highlighted;
  final ValueChanged<AssistantSourceCard>? onDislike;
  final Future<bool> Function(Uri)? openExternal;
  const AssistantResearchSourceCard({
    super.key,
    required this.source,
    required this.index,
    this.highlighted = false,
    this.onDislike,
    this.openExternal,
  });
  @override
  State<AssistantResearchSourceCard> createState() =>
      _AssistantResearchSourceCardState();
}

class _AssistantResearchSourceCardState
    extends State<AssistantResearchSourceCard> {
  bool _expanded = false;
  String? _error;
  Future<void> _open() async {
    final source = widget.source;
    if (!source.available) return;
    if (source.kind == 'post' && jsonInt64IsPositive(source.authorityId)) {
      context.push('/post/${jsonInt64Id(source.authorityId)}');
      return;
    }
    final uri = Uri.tryParse(source.url);
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      setState(() => _error = '来源地址不可用');
      return;
    }
    try {
      final opened =
          await (widget.openExternal?.call(uri) ??
              launchUrl(
                uri,
                mode: LaunchMode.externalApplication,
                webOnlyWindowName: '_blank',
              ));
      if (mounted) setState(() => _error = opened ? null : '无法打开原文');
    } catch (_) {
      if (mounted) setState(() => _error = '无法打开原文');
    }
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.source;
    final theme = context.theme;
    final thumbnail = _trustedThumbnail(source.thumbnailUrl);
    final excerpt = source.excerpts.map((item) => item.text).join('\n\n');
    final site = source.kind == 'post'
        ? '社区帖子'
        : Uri.tryParse(source.url)?.host ?? '外部网页';
    return FCard(
      style: AppTheme.assistantCard,
      clipBehavior: Clip.antiAlias,
      child: ColoredBox(
        color: widget.highlighted
            ? theme.colors.secondary
            : theme.colors.background,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              source.kind == 'post'
                                  ? FLucideIcons.fileText
                                  : FLucideIcons.globe,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '[${widget.index}] $site',
                                style: theme.typography.body.xs.copyWith(
                                  color: theme.colors.mutedForeground,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          source.available ? source.title : '来源已失效',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.typography.body.md,
                        ),
                        if (source.author.isNotEmpty)
                          Text(
                            source.author,
                            style: theme.typography.body.xs,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (source.available &&
                      source.kind == 'post' &&
                      thumbnail != null) ...[
                    const SizedBox(width: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        thumbnail,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 72,
                          height: 72,
                          child: Icon(FLucideIcons.imageOff),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (source.available && excerpt.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  excerpt,
                  key: Key('source-excerpt-${source.handle}'),
                  maxLines: _expanded ? null : 3,
                  overflow: _expanded
                      ? TextOverflow.visible
                      : TextOverflow.ellipsis,
                  style: theme.typography.body.sm,
                ),
                const SizedBox(height: 6),
                Text(
                  source.kind == 'web'
                      ? '搜索摘录'
                      : source.excerpts.any((item) => item.kind == 'comment')
                      ? '含评论摘录'
                      : '原文摘录',
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
              ],
              if (source.available) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    FButton(
                      key: Key('source-open-${source.handle}'),
                      size: .sm,
                      variant: .secondary,
                      onPress: _open,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FLucideIcons.externalLink, size: 14),
                          SizedBox(width: 6),
                          Text('查看原文'),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (excerpt.isNotEmpty)
                      FTooltip(
                        tipBuilder: (_, _) => Text(_expanded ? '收起摘录' : '展开摘录'),
                        child: FButton.icon(
                          key: Key('source-expand-${source.handle}'),
                          variant: .ghost,
                          onPress: () => setState(() => _expanded = !_expanded),
                          child: Icon(
                            _expanded
                                ? FLucideIcons.chevronUp
                                : FLucideIcons.chevronDown,
                            semanticLabel: _expanded ? '收起摘录' : '展开摘录',
                          ),
                        ),
                      ),
                    if (source.kind == 'post' && widget.onDislike != null)
                      FTooltip(
                        tipBuilder: (_, _) => const Text('不感兴趣'),
                        child: FButton.icon(
                          variant: .ghost,
                          onPress: () => widget.onDislike!(
                            AssistantSourceCard(
                              handle: source.handle,
                              kind: source.kind,
                              authorityId: source.authorityId,
                              title: source.title,
                            ),
                          ),
                          child: const Icon(
                            FLucideIcons.thumbsDown,
                            semanticLabel: '不感兴趣',
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: theme.typography.body.sm.copyWith(
                      color: theme.colors.destructive,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _trustedThumbnail(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null ||
      !uri.path.startsWith('/xbh-media/') ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  final base = apiUri('/');
  final origin = base.hasAuthority ? base : Uri.base;
  if (uri.hasAuthority && uri.authority != origin.authority) return null;
  if (uri.hasScheme && !{'http', 'https'}.contains(uri.scheme)) return null;
  return uri.hasAuthority ? uri.toString() : apiUri(raw).toString();
}
