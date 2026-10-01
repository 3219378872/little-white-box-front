import 'dart:convert';

import '../../../core/api/json_int64.dart';

/// 送审时冻结的快照（后端 `event.ReviewSnapshot`）；解析失败时字段为空，不抛出。
class ReviewSnapshotView {
  final Map<String, String> texts;
  final String landingUrl;
  final List<ReviewSnapshotMedia> media;
  final String market;
  final String language;
  final String industry;
  final List<ReviewSnapshotQualification> qualifications;
  final bool valid;

  const ReviewSnapshotView({
    this.texts = const {},
    this.landingUrl = '',
    this.media = const [],
    this.market = '',
    this.language = '',
    this.industry = '',
    this.qualifications = const [],
    this.valid = false,
  });

  /// 文案按固定顺序展示，其余字段排在后面。
  List<MapEntry<String, String>> get orderedTexts {
    const order = ['advertiser', 'name', 'markets', 'title', 'body', 'cta'];
    final known = [
      for (final key in order)
        if (texts.containsKey(key)) MapEntry(key, texts[key]!),
    ];
    final rest =
        texts.entries.where((entry) => !order.contains(entry.key)).toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return [...known, ...rest];
  }

  /// 落地页主机名，用于高亮域名；地址无效时为空。
  String get landingHost {
    final uri = Uri.tryParse(landingUrl);
    return uri == null ? '' : uri.host;
  }

  factory ReviewSnapshotView.parse(String raw) {
    Object? decoded;
    try {
      decoded = decodeApiJson(raw);
    } catch (_) {
      return const ReviewSnapshotView();
    }
    if (decoded is! Map) return const ReviewSnapshotView();
    final nested = decoded['snapshot'];
    final map = nested is Map ? nested : decoded;
    final texts = map['texts'];
    final media = map['media'];
    final qualifications = map['qualifications'];
    return ReviewSnapshotView(
      texts: texts is Map
          ? {
              for (final entry in texts.entries)
                entry.key.toString(): entry.value?.toString() ?? '',
            }
          : const {},
      landingUrl: _text(map['landingUrl']),
      media: media is List
          ? media
                .whereType<Map>()
                .map(
                  (item) => ReviewSnapshotMedia(
                    mediaId: item['mediaId'] ?? 0,
                    sha256: _text(item['sha256']),
                    kind: _text(item['kind']),
                  ),
                )
                .where((item) => jsonInt64IsPositive(item.mediaId))
                .toList()
          : const [],
      market: _text(map['market']),
      language: _text(map['language']),
      industry: _text(map['industry']),
      qualifications: qualifications is List
          ? qualifications
                .whereType<Map>()
                .map(
                  (item) => ReviewSnapshotQualification(
                    market: _text(item['market']),
                    industry: _text(item['industry']),
                    documentMediaId: item['documentMediaId'] ?? 0,
                    validUntilMs: item['validUntilMs'] is int
                        ? item['validUntilMs'] as int
                        : 0,
                  ),
                )
                .toList()
          : const [],
      valid: true,
    );
  }
}

class ReviewSnapshotMedia {
  final Object mediaId;
  final String sha256;
  final String kind;

  const ReviewSnapshotMedia({
    required this.mediaId,
    required this.sha256,
    required this.kind,
  });
}

class ReviewSnapshotQualification {
  final String market;
  final String industry;
  final Object documentMediaId;
  final int validUntilMs;

  const ReviewSnapshotQualification({
    required this.market,
    required this.industry,
    required this.documentMediaId,
    required this.validUntilMs,
  });
}

/// 机审阶段输出的可读行：键值对按 JSON 结构展开，解析失败时保留原文。
List<MapEntry<String, String>> reviewStageOutputRows(String raw) {
  if (raw.trim().isEmpty) return const [];
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return [MapEntry('output', raw)];
  }
  if (decoded is! Map) return [MapEntry('output', jsonEncode(decoded))];
  return [
    for (final entry in decoded.entries)
      MapEntry(
        entry.key.toString(),
        entry.value is String ? entry.value as String : jsonEncode(entry.value),
      ),
  ];
}

/// 占位模型（如 `stub-v0`）的输出不代表真实判断，界面需标注。
bool isPlaceholderComponent(String version) =>
    version.toLowerCase().contains('stub');

String _text(Object? value) => value is String ? value : '';
