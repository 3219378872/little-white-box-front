import '../../../sdk/data/gateway.dart';

/// 首页信息流类型：推荐（匿名可看）与关注（需登录）。
enum FeedKind { recommend, follow }

/// 条目在本次信息流请求中的上下文，随曝光、点击、停留等行为上报给推荐系统。
class FeedRecommendationContext {
  final String requestId;
  final String scene;

  /// 条目在本轮请求快照中的位置（从 1 开始），广告槽位据此锚定。
  final int position;
  final double score;
  final String reason;
  final String recallSource;
  final String modelVersion;
  final String experimentId;

  const FeedRecommendationContext({
    required this.requestId,
    required this.scene,
    required this.position,
    this.score = 0,
    this.reason = '',
    required this.recallSource,
    required this.modelVersion,
    required this.experimentId,
  });
}

/// 信息流中的一条自然内容：帖子及其推荐上下文。
class FeedEntry {
  final PostItem post;
  final FeedRecommendationContext context;

  const FeedEntry({required this.post, required this.context});
}

/// 「为什么看到这条广告」的服务端参数（FX-101）。
class SponsoredWhy {
  final String market;
  final String scene;
  final bool personalized;

  const SponsoredWhy({
    this.market = '',
    this.scene = '',
    this.personalized = false,
  });
}

/// 推荐流中一条带标识的广告（FX-100）。
class SponsoredAd {
  final Object adId;
  final int revision;
  final String advertiserName;
  final String title;
  final String body;
  final String cta;
  final Uri landingUri;
  final String landingDomain;
  final List<String> images;
  final SponsoredWhy why;

  const SponsoredAd({
    required this.adId,
    required this.revision,
    required this.advertiserName,
    required this.title,
    required this.body,
    required this.cta,
    required this.landingUri,
    required this.landingDomain,
    required this.images,
    required this.why,
  });
}

/// 服务端返回的广告槽位；afterPosition 指向本次推荐请求中自然条目的 position。
class SponsoredSlot {
  final String slotId;
  final int afterPosition;
  final SponsoredAd ad;
  final FeedRecommendationContext context;

  const SponsoredSlot({
    required this.slotId,
    required this.afterPosition,
    required this.ad,
    required this.context,
  });

  /// 后端每页的 slotId 都从 `s1` 编号，跨页唯一需要带上 afterPosition。
  String get key => 'ad-${context.requestId}-$afterPosition-$slotId';
}

/// 列表展示行：自然内容与广告分开建模，帖子去重与位置计数只看自然条目（FX-103）。
sealed class FeedRow {
  const FeedRow();
}

/// 自然内容行。
final class FeedPostRow extends FeedRow {
  final FeedEntry entry;

  const FeedPostRow(this.entry);
}

/// 广告行。
final class FeedAdRow extends FeedRow {
  final SponsoredSlot slot;

  const FeedAdRow(this.slot);
}

/// 把广告插到同一请求中 position 等于 afterPosition 的自然条目之后；找不到锚点的槽位丢弃。
List<FeedRow> mergeFeedRows(
  List<FeedEntry> entries,
  List<SponsoredSlot> sponsored,
) {
  if (sponsored.isEmpty) {
    return [for (final entry in entries) FeedPostRow(entry)];
  }
  // 以「请求 ID:位置」为锚点分组，避免不同请求快照的同号位置互相串位。
  final byAnchor = <String, List<SponsoredSlot>>{};
  for (final slot in sponsored) {
    byAnchor
        .putIfAbsent(
          '${slot.context.requestId}:${slot.afterPosition}',
          () => [],
        )
        .add(slot);
  }
  final rows = <FeedRow>[];
  for (final entry in entries) {
    rows.add(FeedPostRow(entry));
    final anchored = byAnchor.remove(
      '${entry.context.requestId}:${entry.context.position}',
    );
    if (anchored != null) rows.addAll(anchored.map(FeedAdRow.new));
  }
  return rows;
}

/// 关注流的复合游标：上一页最后一条的创建时间与帖子 ID；全 0 表示第一页。
class FollowFeedCursor {
  final int createdAt;
  final Object postId;

  const FollowFeedCursor({this.createdAt = 0, this.postId = 0});
}

/// 仓储返回的一页信息流：自然条目、分页游标与广告槽位。
class FeedPageResult {
  final List<FeedEntry> items;
  final bool hasMore;
  final String requestId;
  final String recommendCursor;
  final FollowFeedCursor followCursor;
  final List<SponsoredSlot> sponsored;

  /// 本页因格式错误被丢弃的广告槽位数（FX-103）。
  final int droppedSponsored;

  const FeedPageResult({
    required this.items,
    required this.hasMore,
    required this.requestId,
    this.recommendCursor = '',
    this.followCursor = const FollowFeedCursor(),
    this.sponsored = const [],
    this.droppedSponsored = 0,
  });
}
