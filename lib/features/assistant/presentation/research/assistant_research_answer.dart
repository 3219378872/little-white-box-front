import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../../../core/widgets/app_badge.dart';
import '../../data/assistant_models.dart';
import 'assistant_research_source_card.dart';

/// 结构化研究回答：按块渲染正文与引用角标，点击角标滚动并高亮对应来源卡片。
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

// 为每个来源 handle 保留 GlobalKey，供引用跳转时定位卡片。
class _AssistantResearchAnswerState extends State<AssistantResearchAnswer> {
  final _keys = <String, GlobalKey>{};
  String? _highlighted;

  // 先高亮再滚动，使来源卡片出现在视口上部；减少动画时直接跳转。
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
          // 链接与图片一律不在正文内打开，外部内容只能经来源卡片的安全入口访问。
          GptMarkdown(
            block.text,
            style: theme.typography.body.md,
            onLinkTap: (_, _) {},
            imageBuilder: (_, _, _, _) => const SizedBox.shrink(),
          ),
          if (block.citations.isNotEmpty)
            _CitationLinks(block: block, sources: sources, onReveal: _reveal),
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

// 一个回答块的引用角标：按来源顺序编号，失效来源追加提示；同一来源只出现一次。
class _CitationLinks extends StatelessWidget {
  final AssistantAnswerBlock block;
  final List<AssistantResearchSource> sources;
  final ValueChanged<String> onReveal;

  const _CitationLinks({
    required this.block,
    required this.sources,
    required this.onReveal,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: [
        for (final handle
            in block.citations.map((citation) => citation.handle).toSet())
          SystemFontsRefresh(
            child: IntrinsicWidth(
              child: FButton(
                key: Key('citation-${block.id}-$handle'),
                variant: .ghost,
                size: .sm,
                onPress: () => onReveal(handle),
                child: Text(
                  '[${sources.indexWhere((source) => source.handle == handle) + 1}]${sources.any((source) => source.handle == handle && !source.available) ? ' 来源失效' : ''}',
                ),
              ),
            ),
          ),
      ],
    );
  }
}
