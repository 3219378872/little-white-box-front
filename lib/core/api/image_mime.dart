/// 识别图片 MIME 至少需要的文件头字节数（WebP 的 `RIFF....WEBP`）。
const imageMimeSniffLength = 12;

/// 按扩展名、再按文件头魔数识别后端白名单内的图片 MIME（jpeg/png/webp）。
///
/// 无法识别时返回 null，供发帖等需要在上传前拒绝不支持格式的场景判断。
String? detectImageMime(String filename, List<int> head) {
  // 扩展名优先：与选择器展示给用户的文件类型一致。
  switch (filename.toLowerCase().split('.').last) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
  }
  // 无可用扩展名时按魔数识别：JPEG `FF D8 FF`、PNG `89 50 4E 47`、WebP `RIFF....WEBP`。
  if (_startsWith(head, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (_startsWith(head, const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
  if (_startsWith(head, const [0x52, 0x49, 0x46, 0x46]) &&
      _startsWith(head, const [0x57, 0x45, 0x42, 0x50], offset: 8)) {
    return 'image/webp';
  }
  return null;
}

/// 上传时声明的图片 MIME；识别不出时回退 `image/jpeg`，最终格式仍由服务端内容嗅探裁定。
String inferImageMime(String filename, List<int> head) {
  return detectImageMime(filename, head) ?? 'image/jpeg';
}

// 判断 [bytes] 在 [offset] 处是否以 [magic] 开头；头部字节不足时视为不匹配。
bool _startsWith(List<int> bytes, List<int> magic, {int offset = 0}) {
  if (bytes.length < offset + magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (bytes[offset + i] != magic[i]) return false;
  }
  return true;
}
