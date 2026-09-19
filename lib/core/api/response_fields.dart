/// Required fields are checked before applying Go's nil-slice compatibility.
/// A missing field is a contract failure, not an empty collection or zero count.
List<dynamic> requiredResponseList(Map<String, dynamic> response, String key) {
  if (!response.containsKey(key)) {
    throw FormatException('missing $key');
  }
  final value = response[key];
  if (value == null) return const [];
  if (value is! List) throw FormatException('invalid $key');
  return value;
}

int requiredResponseCount(Map<String, dynamic> response, String key) {
  final value = response[key];
  if (value is! int || value < 0) {
    throw FormatException('invalid $key');
  }
  return value;
}
