import 'package:flutter_test/flutter_test.dart';
import 'package:xiaobaihe_app/core/formatters/time_formatter.dart';

void main() {
  final now = DateTime(2026, 9, 5, 12);

  test('converts backend milliseconds and legacy seconds to the same time', () {
    final instant = DateTime(2026, 9, 5, 8, 7);

    expect(dateTimeFromUnixTimestamp(instant.millisecondsSinceEpoch), instant);
    expect(
      dateTimeFromUnixTimestamp(
        instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
      ),
      instant,
    );
  });

  test('formats relative time with an injected clock', () {
    final thirtyMinutesAgo = now.subtract(const Duration(minutes: 30));
    final old = DateTime(2026, 7, 3);

    expect(
      formatRelativeTime(thirtyMinutesAgo.millisecondsSinceEpoch, now: now),
      '30分钟前',
    );
    expect(
      formatRelativeTime(
        thirtyMinutesAgo.millisecondsSinceEpoch ~/
            Duration.millisecondsPerSecond,
        now: now,
      ),
      '30分钟前',
    );
    expect(formatRelativeTime(old.millisecondsSinceEpoch, now: now), '07-03');
    expect(
      formatRelativeTime(
        old.millisecondsSinceEpoch,
        now: now,
        includeYear: true,
      ),
      '2026-07-03',
    );
  });

  test('formats message clocks for milliseconds and seconds', () {
    final instant = DateTime(2026, 9, 5, 8, 7);

    expect(formatClockTime(instant.millisecondsSinceEpoch), '08:07');
    expect(
      formatClockTime(
        instant.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
      ),
      '08:07',
    );
    expect(formatClockTime(0), isEmpty);
  });

  test('formats conversation time against an injected current day', () {
    final sameDay = DateTime(2026, 9, 5, 8, 7);
    final previousDay = DateTime(2026, 9, 4, 23, 59);

    expect(
      formatConversationTime(sameDay.millisecondsSinceEpoch, now: now),
      '08:07',
    );
    expect(
      formatConversationTime(
        previousDay.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond,
        now: now,
      ),
      '9/4',
    );
    expect(formatConversationTime(0, now: now), isEmpty);
  });

  test('formats UTC dates independent of the local zone', () {
    // 23:30 UTC 在东八区已是次日，日期仍按 UTC 日界展示。
    final lateUtc = DateTime.utc(2026, 3, 9, 23, 30).millisecondsSinceEpoch;
    expect(formatUtcDate(lateUtc), '2026-03-09');
  });

  test('formats countdowns as unpadded minutes and padded seconds', () {
    expect(
      formatMinutesSeconds(const Duration(minutes: 4, seconds: 5)),
      '4:05',
    );
    expect(formatMinutesSeconds(const Duration(seconds: 59)), '0:59');
    expect(formatMinutesSeconds(const Duration(minutes: 75)), '75:00');
  });
}
