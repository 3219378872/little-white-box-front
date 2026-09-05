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
    expect(formatRelativeTime(old.millisecondsSinceEpoch, now: now), '7-3');
    expect(
      formatRelativeTime(
        old.millisecondsSinceEpoch,
        now: now,
        includeYear: true,
      ),
      '2026-7-3',
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
}
