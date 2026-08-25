import 'dart:convert';

/// Flutter Web (dart2js/DDC) 把 JSON number 当成 IEEE-754，超过 2^53-1 的雪花 ID
/// 会在 jsonDecode 时丢位，toString() 还会再改写成另一串十进制。
///
/// 对策：解码前把 16 位及以上的整数字面量改成 JSON 字符串；编码后再把这类
/// 字符串值还原成 JSON number，让 Go 的 int64 仍能收下。
const jsonInt64DigitThreshold = 16;

final _digitsOnly = RegExp(r'^-?\d+$');

dynamic decodeApiJson(String source) {
  if (source.isEmpty) return null;
  return jsonDecode(quoteLargeJsonInts(source));
}

String encodeApiJson(Object? data) {
  if (data == null) return '';
  return unquoteLargeJsonIntStrings(jsonEncode(data));
}

/// Canonical decimal form for entity IDs used in URLs, query and JSON.
String jsonInt64Id(Object? value) {
  if (value == null) return '0';
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '0' : trimmed;
  }
  if (value is int) return value.toString();
  if (value is num) {
    if (value.isFinite &&
        value == value.roundToDouble() &&
        value.abs() <= 9007199254740991) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(0);
  }
  return value.toString();
}

bool jsonInt64IsPositive(Object? value) {
  final id = jsonInt64Id(value);
  if (id.startsWith('-') || id == '0') return false;
  return _digitsOnly.hasMatch(id);
}

String quoteLargeJsonInts(String source) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  var escaped = false;
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (inString) {
      out.writeCharCode(unit);
      if (escaped) {
        escaped = false;
      } else if (unit == 0x5c) {
        escaped = true;
      } else if (unit == 0x22) {
        inString = false;
      }
      i++;
      continue;
    }
    if (unit == 0x22) {
      inString = true;
      out.writeCharCode(unit);
      i++;
      continue;
    }
    final negative = unit == 0x2d;
    final isDigit = unit >= 0x30 && unit <= 0x39;
    if (!negative && !isDigit) {
      out.writeCharCode(unit);
      i++;
      continue;
    }
    if (negative &&
        (i + 1 >= source.length ||
            source.codeUnitAt(i + 1) < 0x30 ||
            source.codeUnitAt(i + 1) > 0x39)) {
      out.writeCharCode(unit);
      i++;
      continue;
    }
    final start = i;
    if (negative) i++;
    final digitStart = i;
    while (i < source.length) {
      final digit = source.codeUnitAt(i);
      if (digit < 0x30 || digit > 0x39) break;
      i++;
    }
    // 如果是小数或科学计数法，按浮点数整体跳过，不做 quoting。
    if (i < source.length) {
      final next = source.codeUnitAt(i);
      if (next == 0x2e) {
        // '.' + digits
        var j = i + 1;
        while (j < source.length) {
          final d = source.codeUnitAt(j);
          if (d < 0x30 || d > 0x39) break;
          j++;
        }
        if (j > i + 1) {
          i = j;
          if (i < source.length) {
            final exp = source.codeUnitAt(i);
            if (exp == 0x65 || exp == 0x45) {
              var k = i + 1;
              if (k < source.length) {
                final sign = source.codeUnitAt(k);
                if (sign == 0x2b || sign == 0x2d) k++;
              }
              var expStart = k;
              while (k < source.length) {
                final d = source.codeUnitAt(k);
                if (d < 0x30 || d > 0x39) break;
                k++;
              }
              if (k > expStart) i = k;
            }
          }
          out.write(source.substring(start, i));
          continue;
        }
      } else if (next == 0x65 || next == 0x45) {
        var k = i + 1;
        if (k < source.length) {
          final sign = source.codeUnitAt(k);
          if (sign == 0x2b || sign == 0x2d) k++;
        }
        var expStart = k;
        while (k < source.length) {
          final d = source.codeUnitAt(k);
          if (d < 0x30 || d > 0x39) break;
          k++;
        }
        if (k > expStart) {
          i = k;
          out.write(source.substring(start, i));
          continue;
        }
      }
    }
    if (i > digitStart && i - digitStart >= jsonInt64DigitThreshold) {
      out.write('"');
      out.write(source.substring(start, i));
      out.write('"');
      continue;
    }
    out.write(source.substring(start, i));
  }
  return out.toString();
}

/// 仅当值所属的键名以 `Id`/`Ids` 结尾时才把 ≥16 位的数字字符串还原成 JSON
/// number；正文、标题等自由文本里的长数字串（订单号、手机号）必须原样保留，
/// 否则会被网关的 string 字段拒绝。数组元素继承所属键名（如 `postIds`）。
String unquoteLargeJsonIntStrings(String source) {
  final out = StringBuffer();
  var i = 0;
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  String? lastKey;
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (!inString) {
      if (unit == 0x7b || unit == 0x7d) {
        // 对象开/闭都会切换作用域，清掉上一个键名。
        lastKey = null;
      }
      if (unit == 0x22) {
        inString = true;
        escaped = false;
        stringStart = i;
      } else {
        out.writeCharCode(unit);
      }
      i++;
      continue;
    }
    if (escaped) {
      escaped = false;
      i++;
      continue;
    }
    if (unit == 0x5c) {
      escaped = true;
      i++;
      continue;
    }
    if (unit != 0x22) {
      i++;
      continue;
    }
    final content = source.substring(stringStart + 1, i);
    i++;
    inString = false;
    if (_nextNonSpaceIsColon(source, i)) {
      // 这是键名字符串，记录后原样写出。
      lastKey = content;
      out.write('"');
      out.write(content);
      out.write('"');
      continue;
    }
    final keyQualifies =
        lastKey != null && (lastKey.endsWith('Id') || lastKey.endsWith('Ids'));
    final isLargeInt =
        keyQualifies &&
            !content.startsWith('0') &&
            !content.startsWith('-0') &&
            _digitsOnly.hasMatch(content) &&
            content.replaceFirst('-', '').length >= jsonInt64DigitThreshold;
    if (isLargeInt) {
      out.write(content);
    } else {
      out.write('"');
      out.write(content);
      out.write('"');
    }
  }
  if (inString) {
    out.write(source.substring(stringStart));
  }
  return out.toString();
}

bool _nextNonSpaceIsColon(String source, int i) {
  while (i < source.length) {
    final unit = source.codeUnitAt(i);
    if (unit == 0x20 || unit == 0x09 || unit == 0x0a || unit == 0x0d) {
      i++;
      continue;
    }
    return unit == 0x3a;
  }
  return false;
}
