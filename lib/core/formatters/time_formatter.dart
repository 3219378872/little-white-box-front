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
  return includeYear
      ? '${date.year}-${date.month}-${date.day}'
      : '${date.month}-${date.day}';
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

String _twoDigits(int value) => value.toString().padLeft(2, '0');
