import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/feed_models.dart';
import 'feed_notifier.dart';

class TrendingTag {
  final String name;
  final int postCount;

  const TrendingTag(this.name, this.postCount);
}

/// Ranks tags across already loaded feed entries.
///
/// There is no server-side trending endpoint; this is a client-side
/// approximation over the posts the user has in the recommend feed and never
/// triggers an extra request. Tags seen on fewer than [minPosts] loaded posts
/// are dropped so a thin feed does not present one-off tags as trends.
List<TrendingTag> rankTrendingTags(
  Iterable<FeedEntry> entries, {
  int limit = 10,
  int minPosts = 2,
}) {
  final counts = <String, int>{};
  final firstSeen = <String, int>{};
  var order = 0;
  for (final entry in entries) {
    for (final raw in entry.post.tags.toSet()) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
      firstSeen.putIfAbsent(tag, () => order++);
    }
  }
  final ranked = counts.entries.where((e) => e.value >= minPosts).toList()
    ..sort((a, b) {
      final byCount = b.value.compareTo(a.value);
      return byCount != 0
          ? byCount
          : firstSeen[a.key]!.compareTo(firstSeen[b.key]!);
    });
  return [
    for (final entry in ranked.take(limit)) TrendingTag(entry.key, entry.value),
  ];
}

final trendingTagsProvider = Provider.autoDispose<List<TrendingTag>>((ref) {
  final entries = ref.watch(
    feedNotifierProvider(FeedKind.recommend).select((state) => state.entries),
  );
  return rankTrendingTags(entries);
});
