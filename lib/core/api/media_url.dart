import '../../sdk/vars/vars.dart';

/// 把服务端返回的图片地址解析为可直接加载的 URL。
///
/// 带协议的绝对地址原样返回；站内相对路径（如 `/xbh-media/...`）经 [apiUri] 拼到网关源，
/// [host] 仅供测试覆盖默认的 `SERVER_HOST`。
String resolveImageUrl(String raw, {String? host}) {
  final uri = Uri.parse(raw);
  return uri.hasScheme ? raw : apiUri(raw, host: host).toString();
}
