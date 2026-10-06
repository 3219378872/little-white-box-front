import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/api/api_exceptions.dart';
import '../../../core/api/json_int64.dart';
import '../../../core/formatters/time_formatter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_section.dart';
import '../../../sdk/data/gateway.dart';
import '../../ads/data/ad_labels.dart';
import '../data/review_repository.dart';
import '../data/review_snapshot.dart';

final reviewMediaProvider = FutureProvider.autoDispose
    .family<ReviewMediaContent, (String, String)>((ref, key) {
      return ref.read(reviewRepositoryProvider).media(key.$1, key.$2);
    });

/// 快照与机审证据，分段折叠以适配移动端单列（FX-111、FQ-005）。
class ReviewEvidence extends StatelessWidget {
  final ReviewTaskItem task;

  const ReviewEvidence({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final snapshot = ReviewSnapshotView.parse(task.snapshotJson);
    return FAccordion(
      children: [
        FAccordionItem(
          initiallyExpanded: true,
          title: const Text('送审快照'),
          child: _SnapshotView(
            taskId: jsonInt64Id(task.taskId),
            snapshot: snapshot,
          ),
        ),
        FAccordionItem(
          initiallyExpanded: true,
          title: Text('机审证据（${task.stages.length}）'),
          child: _StagesView(stages: task.stages),
        ),
      ],
    );
  }
}

class _SnapshotView extends StatelessWidget {
  final String taskId;
  final ReviewSnapshotView snapshot;

  const _SnapshotView({required this.taskId, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (!snapshot.valid) {
      return Text(
        '快照无法解析',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.destructive,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final entry in snapshot.orderedTexts)
          AppInfoRow(
            label: reviewSnapshotTextLabel(entry.key),
            value: Text(entry.value),
          ),
        if (snapshot.landingUrl.isNotEmpty)
          AppInfoRow(
            label: '落地页',
            value: LandingUrlText(url: snapshot.landingUrl),
          ),
        AppInfoRow.text(
          label: '市场',
          text: '${adMarketLabel(snapshot.market)} · ${snapshot.language}',
        ),
        if (snapshot.industry.isNotEmpty)
          AppInfoRow.text(
            label: '行业',
            text: adIndustryLabel(snapshot.industry),
          ),
        for (final qualification in snapshot.qualifications)
          AppInfoRow(
            label: '资质',
            value: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${adMarketLabel(qualification.market)} · '
                  '${adIndustryLabel(qualification.industry)} · 有效期至 '
                  '${_date(qualification.validUntilMs)}',
                ),
                if (jsonInt64IsPositive(qualification.documentMediaId))
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.space1),
                    child: ReviewMediaTile(
                      taskId: taskId,
                      mediaId: jsonInt64Id(qualification.documentMediaId),
                    ),
                  ),
              ],
            ),
          ),
        if (snapshot.media.isNotEmpty) ...[
          const SizedBox(height: AppTheme.space2),
          Wrap(
            spacing: AppTheme.space2,
            runSpacing: AppTheme.space2,
            children: [
              for (final media in snapshot.media)
                ReviewMediaTile(
                  taskId: taskId,
                  mediaId: jsonInt64Id(media.mediaId),
                ),
            ],
          ),
        ],
      ],
    );
  }

  // 资质有效期等证据日期按 UTC 展示，0 表示申请方未提供。
  static String _date(int ms) {
    if (ms <= 0) return '未提供';
    return formatUtcDate(ms);
  }
}

/// 纯文本落地页地址，高亮域名，不自动打开（DES「审核工作台」）。
class LandingUrlText extends StatelessWidget {
  final String url;

  const LandingUrlText({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? '';
    final start = host.isEmpty ? -1 : url.indexOf(host);
    if (start < 0) return Text(url);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: url.substring(0, start)),
          TextSpan(
            text: host,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: theme.colors.primary,
              backgroundColor: AppTheme.accentSoft(theme.colors),
            ),
          ),
          TextSpan(text: url.substring(start + host.length)),
        ],
      ),
      semanticsLabel: '落地页 $url，域名 $host',
    );
  }
}

/// 经鉴权接口读取的快照图片或证件。
class ReviewMediaTile extends ConsumerWidget {
  final String taskId;
  final String mediaId;

  const ReviewMediaTile({
    super.key,
    required this.taskId,
    required this.mediaId,
  });

  static const size = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final media = ref.watch(reviewMediaProvider((taskId, mediaId)));
    Widget frame(Widget child) => SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colors.muted,
          borderRadius: AppTheme.imageRadius,
          border: Border.all(color: theme.colors.border),
        ),
        child: ClipRRect(borderRadius: AppTheme.imageRadius, child: child),
      ),
    );
    return media.when(
      loading: () => frame(const Center(child: FCircularProgress())),
      error: (error, _) => frame(
        Center(
          child: Text(
            '读取失败\n${friendlyErrorMessage(error)}',
            textAlign: TextAlign.center,
            style: theme.typography.body.xs,
          ),
        ),
      ),
      data: (content) => content.isImage
          ? frame(
              Image.memory(
                content.bytes,
                fit: BoxFit.cover,
                semanticLabel: '送审素材 $mediaId',
              ),
            )
          : frame(
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FLucideIcons.fileText),
                    const SizedBox(height: AppTheme.space1),
                    Text(
                      '${content.mimeType}\n${content.bytes.length ~/ 1024} KiB',
                      textAlign: TextAlign.center,
                      style: theme.typography.body.xs,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _StagesView extends StatelessWidget {
  final List<ReviewStageItem> stages;

  const _StagesView({required this.stages});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    if (stages.isEmpty) {
      return Text(
        '没有机审记录',
        style: theme.typography.body.sm.copyWith(
          color: theme.colors.mutedForeground,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppTheme.space3,
      children: [for (final stage in stages) _StageTile(stage: stage)],
    );
  }
}

class _StageTile extends StatelessWidget {
  final ReviewStageItem stage;

  const _StageTile({required this.stage});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final placeholder = isPlaceholderComponent(stage.componentVersion);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: theme.colors.border, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppTheme.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppTheme.space2,
              runSpacing: AppTheme.space1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  stage.stage,
                  style: theme.typography.body.sm.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  stage.componentVersion,
                  style: theme.typography.body.xs.copyWith(
                    color: theme.colors.mutedForeground,
                  ),
                ),
                if (placeholder)
                  AppBadge(
                    key: Key('review-stage-placeholder-${stage.stage}'),
                    variant: FBadgeVariant.outline,
                    child: const Text('占位'),
                  ),
                if (stage.shadow)
                  AppBadge(
                    variant: FBadgeVariant.outline,
                    child: const Text('影子'),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '结果：${stage.outcome}'
              '${stage.reason.isEmpty ? '' : ' · ${stage.reason}'}'
              ' · ${stage.latencyMs} ms',
              style: theme.typography.body.xs,
            ),
            if (placeholder)
              Text(
                '占位模型分数不代表真实判断',
                style: theme.typography.body.xs.copyWith(
                  color: theme.colors.mutedForeground,
                ),
              ),
            for (final row in reviewStageOutputRows(stage.outputJson))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${row.key}: ${row.value}',
                  style: theme.typography.body.xs.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colors.secondaryForeground,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
