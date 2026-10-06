import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/json_int64.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../sdk/vars/vars.dart';
import '../../data/assistant_models.dart';

/// 研究回答的单个来源卡片：社区帖子走站内路由，外部网页只以安全的 http(s) 外链打开。
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

// 持有摘录展开状态与打开原文失败时的就地错误提示。
class _AssistantResearchSourceCardState
    extends State<AssistantResearchSourceCard> {
  bool _expanded = false;
  String? _error;

  // 帖子来源进站内详情；外链拒绝非 http(s)、无主机或带用户信息的地址，打开失败就地提示。
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
    final excerpt = source.excerpts.map((item) => item.text).join('\n\n');
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
              _SourceHeading(source: source, index: widget.index),
              if (source.available && excerpt.isNotEmpty)
                _SourceExcerpt(
                  source: source,
                  excerpt: excerpt,
                  expanded: _expanded,
                ),
              if (source.available)
                _SourceActions(
                  source: source,
                  hasExcerpt: excerpt.isNotEmpty,
                  expanded: _expanded,
                  onOpen: _open,
                  onToggleExpanded: () =>
                      setState(() => _expanded = !_expanded),
                  onDislike: widget.onDislike,
                ),
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

// 来源卡片头部：序号与站点、标题、作者；可信的帖子缩略图放在右侧。
class _SourceHeading extends StatelessWidget {
  final AssistantResearchSource source;
  final int index;

  const _SourceHeading({required this.source, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final thumbnail = _trustedThumbnail(source.thumbnailUrl);
    final site = source.kind == 'post'
        ? '社区帖子'
        : Uri.tryParse(source.url)?.host ?? '外部网页';
    return Row(
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
                      '[$index] $site',
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
        if (source.available && source.kind == 'post' && thumbnail != null) ...[
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
    );
  }
}

// 来源摘录：默认折叠为三行，并标注摘录出处（搜索摘录 / 含评论 / 原文）。
class _SourceExcerpt extends StatelessWidget {
  final AssistantResearchSource source;
  final String excerpt;
  final bool expanded;

  const _SourceExcerpt({
    required this.source,
    required this.excerpt,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          excerpt,
          key: Key('source-excerpt-${source.handle}'),
          maxLines: expanded ? null : 3,
          overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
    );
  }
}

// 来源操作行：查看原文、展开/收起摘录，以及仅对社区帖子提供的「不感兴趣」反馈。
class _SourceActions extends StatelessWidget {
  final AssistantResearchSource source;
  final bool hasExcerpt;
  final bool expanded;
  final VoidCallback onOpen;
  final VoidCallback onToggleExpanded;
  final ValueChanged<AssistantSourceCard>? onDislike;

  const _SourceActions({
    required this.source,
    required this.hasExcerpt,
    required this.expanded,
    required this.onOpen,
    required this.onToggleExpanded,
    required this.onDislike,
  });

  @override
  Widget build(BuildContext context) {
    final onDislike = this.onDislike;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            FButton(
              key: Key('source-open-${source.handle}'),
              size: .sm,
              variant: .secondary,
              onPress: onOpen,
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
            if (hasExcerpt)
              FTooltip(
                tipBuilder: (_, _) => Text(expanded ? '收起摘录' : '展开摘录'),
                child: FButton.icon(
                  key: Key('source-expand-${source.handle}'),
                  variant: .ghost,
                  onPress: onToggleExpanded,
                  child: Icon(
                    expanded
                        ? FLucideIcons.chevronUp
                        : FLucideIcons.chevronDown,
                    semanticLabel: expanded ? '收起摘录' : '展开摘录',
                  ),
                ),
              ),
            if (source.kind == 'post' && onDislike != null)
              FTooltip(
                tipBuilder: (_, _) => const Text('不感兴趣'),
                child: FButton.icon(
                  variant: .ghost,
                  onPress: () => onDislike(
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
    );
  }
}

// 只接受同源 /xbh-media/ 下的缩略图，避免来源卡片加载任意第三方图片；相对地址按 API 基址补全。
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
