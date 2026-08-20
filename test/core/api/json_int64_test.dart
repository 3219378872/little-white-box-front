import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:xiaobaihe_app/core/api/json_int64.dart';
import 'package:xiaobaihe_app/sdk/api/api.dart';

void main() {
  const snowflake = '348206251022356480';
  const jsRounded = '348206251022356500';

  test('quotes 16+ digit integers outside JSON strings', () {
    const source =
        '{"postId":348206251022356480,"createdAt":1787057239000,'
        '"title":"id 348206251022356480 stays text","score":0.7854}';
    final quoted = quoteLargeJsonInts(source);
    expect(quoted, contains('"postId":"348206251022356480"'));
    expect(quoted, contains('"createdAt":1787057239000'));
    expect(quoted, contains('"title":"id 348206251022356480 stays text"'));
    expect(quoted, contains('"score":0.7854'));

    final decoded = decodeApiJson(source) as Map<String, dynamic>;
    expect(decoded['postId'], snowflake);
    expect(decoded['createdAt'], 1787057239000);
    expect(jsonInt64Id(decoded['postId']), snowflake);
  });

  test('does not quote safe integers or leading-zero digit strings', () {
    final decoded =
        decodeApiJson('{"id":1299,"revision":1}') as Map<String, dynamic>;
    expect(decoded['id'], 1299);
    expect(jsonInt64Id(decoded['id']), '1299');
    expect(jsonInt64IsPositive(decoded['id']), isTrue);
    expect(jsonInt64IsPositive(0), isFalse);
    expect(jsonInt64IsPositive('0'), isFalse);
  });

  test('encode emits JSON numbers so Go int64 can unmarshal', () {
    final encoded = encodeApiJson({
      'postId': snowflake,
      'targetId': snowflake,
      'title': 'keep $snowflake quoted',
    });
    expect(encoded, contains('"postId":348206251022356480'));
    expect(encoded, contains('"targetId":348206251022356480'));
    expect(encoded, contains('"title":"keep $snowflake quoted"'));
    expect(encoded, isNot(contains('"$snowflake"')));
  });

  test('does not unquote object keys that look like integers', () {
    final encoded = unquoteLargeJsonIntStrings('{"$snowflake":1}');
    expect(encoded, '{"$snowflake":1}');
  });

  test('jsonInt64Id keeps exact digits and rejects JS rounded ids', () {
    expect(jsonInt64Id(snowflake), snowflake);
    expect(jsonInt64Id(int.parse('1299')), '1299');
    expect(snowflake, isNot(jsRounded));
  });

  test('round-trips a recommend-like payload through decode and encode', () {
    const body =
        '{"items":[{"postId":348206251022356480,"authorId":348206249743089664,'
        '"title":"继续联调帖"}]}';
    final decoded = decodeApiJson(body) as Map<String, dynamic>;
    final item = decoded['items'][0] as Map<String, dynamic>;
    expect(jsonInt64Id(item['postId']), snowflake);
    expect(jsonInt64Id(item['authorId']), '348206249743089664');

    final encoded = encodeApiJson({
      'postId': jsonInt64Id(item['postId']),
      'authorId': jsonInt64Id(item['authorId']),
    });
    final reparsed = jsonDecode(encoded) as Map<String, dynamic>;
    expect(jsonInt64Id(reparsed['postId']), snowflake);
  });

  test('apiGet keeps snowflake postId digits from a JSON number body', () async {
    const id = '348206251022356480';
    setApiClient(_RawJsonClient('{"id":$id,"title":"继续联调帖"}'));
    Map<String, dynamic>? data;
    await apiGet(
      '/api/v1/post/$id',
      ok: (decoded) => data = decoded,
      fail: (error) => fail(error),
    );
    expect(jsonInt64Id(data?['id']), id);
    expect(data?['title'], '继续联调帖');
  });
}

class _RawJsonClient extends http.BaseClient {
  final String body;

  _RawJsonClient(this.body);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(body)),
      200,
      headers: const {'content-type': 'application/json'},
    );
  }
}
