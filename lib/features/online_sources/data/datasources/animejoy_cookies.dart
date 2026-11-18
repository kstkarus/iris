import 'dart:io';

/// Cookies for one HTTPS origin. The caller checks the origin before requests.
class AnimejoyCookies {
  final _cookies = <(String, String), Cookie>{};

  void accept(Uri uri, Iterable<String> headers) {
    final now = DateTime.now();
    for (final header in headers) {
      final Cookie cookie;
      try {
        cookie = Cookie.fromSetCookieValue(header);
      } on FormatException {
        continue;
      }
      final domain = cookie.domain?.toLowerCase().replaceFirst(
        RegExp(r'^\.'),
        '',
      );
      if (domain != null && domain != uri.host) continue;

      final path = cookie.path;
      final requestPath = uri.path;
      final lastSlash = requestPath.lastIndexOf('/');
      final cookiePath = path != null && path.startsWith('/')
          ? path
          : lastSlash > 0
          ? requestPath.substring(0, lastSlash)
          : '/';
      final maxAge = cookie.maxAge;
      final expires = maxAge == null
          ? cookie.expires
          : now.add(Duration(seconds: maxAge));
      final key = (cookie.name, cookiePath);
      if (expires != null && !expires.isAfter(now)) {
        _cookies.remove(key);
        continue;
      }
      _cookies[key] = cookie
        ..domain = null
        ..path = cookiePath
        ..maxAge = null
        ..expires = expires;
    }
  }

  String? headerFor(Uri uri) {
    _removeExpired();
    final path = uri.path.isEmpty ? '/' : uri.path;
    final matching = [
      for (final cookie in _cookies.values)
        if (_matchesPath(path, cookie.path!)) cookie,
    ]..sort((a, b) => b.path!.length.compareTo(a.path!.length));
    if (matching.isEmpty) return null;
    return matching
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
  }

  List<String> persistent() {
    _removeExpired();
    return [
      for (final cookie in _cookies.values)
        if (cookie.expires != null) cookie.toString(),
    ];
  }

  void _removeExpired() {
    final now = DateTime.now();
    _cookies.removeWhere((_, cookie) => cookie.expires?.isAfter(now) == false);
  }

  static bool _matchesPath(String request, String cookie) =>
      request == cookie ||
      request.startsWith(cookie.endsWith('/') ? cookie : '$cookie/');
}
