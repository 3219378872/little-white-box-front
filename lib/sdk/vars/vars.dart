/// Optional absolute API origin. Empty (the default) keeps request URIs
/// relative, e.g. `/api/v1/health`, so the browser uses the current origin.
const serverHost = String.fromEnvironment('SERVER_HOST', defaultValue: '');

/// Builds a request URI from a gateway [path] such as `/api/v1/health`.
///
/// When [serverHost] is empty the path stays relative. A non-empty host is
/// joined without a double slash. Native or explicit overrides can still pass
/// `SERVER_HOST=http://127.0.0.1:8888`.
Uri apiUri(String path, {String? host}) {
  final normalized = path.startsWith('/') ? path : '/$path';
  final base = (host ?? serverHost).trim();
  if (base.isEmpty) {
    return Uri.parse(normalized);
  }
  final origin = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  return Uri.parse('$origin$normalized');
}
