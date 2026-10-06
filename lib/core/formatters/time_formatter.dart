const _unixMillisecondsThreshold = 100000000000;

/// Converts current millisecond timestamps and legacy second timestamps to a
/// local [DateTime].
DateTime dateTimeFromUnixTimestamp(num timestamp) {
  final value = timestamp.toInt();
  final milliseconds = value.abs() >= _unixMillisecondsThreshold
      ? value
      : value * Duration.millisecondsPerSecond;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
}

String formatRelativeTime(
  num timestamp, {
  DateTime? now,
  bool includeYear = false,
}) {
  final date = dateTimeFromUnixTimestamp(timestamp);
  final diff = (now ?? DateTime.now()).difference(date);
  if (diff.inMinutes < 1) return '刚刚';
  if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
  if (diff.inDays < 1) return '${diff.inHours}小时前';
  if (diff.inDays < 30) return '${diff.inDays}天前';
  // Zero-padded so dates line up across feed, detail and comments.
  final monthDay = '${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  return includeYear ? '${date.year}-$monthDay' : monthDay;
}

String formatClockTime(num timestamp) {
  if (timestamp <= 0) return '';
  final value = dateTimeFromUnixTimestamp(timestamp);
  return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
}

String formatConversationTime(num timestamp, {DateTime? now}) {
  if (timestamp <= 0) return '';
  final value = dateTimeFromUnixTimestamp(timestamp);
  final current = now ?? DateTime.now();
  if (value.year == current.year &&
      value.month == current.month &&
      value.day == current.day) {
    return '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';
  }
  return '${value.month}/${value.day}';
}

/// 以 UTC 展示 `YYYY-MM-DD`，供广告有效期、审核证据等按 UTC 日界存储的日期使用。
String formatUtcDate(int epochMilliseconds) {
  final date = DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds,
    isUtc: true,
  );
  return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
}

/// 倒计时文案 `分:秒`，分钟不补零、秒补两位，如 `4:05`。
String formatMinutesSeconds(Duration duration) {
  final seconds = duration.inSeconds % Duration.secondsPerMinute;
  return '${duration.inMinutes}:${_twoDigits(seconds)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
