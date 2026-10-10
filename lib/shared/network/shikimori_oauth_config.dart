/// The app's Shikimori OAuth application.
///
/// The id and secret come from a local, git-ignored file passed at build
/// time (`--dart-define-from-file=config/shikimori.json`, see README); a
/// build without it runs, only without sign-in.
class ShikimoriOAuthConfig {
  const ShikimoriOAuthConfig({
    required this.clientId,
    required this.clientSecret,
    this.redirectUri = appRedirectUri,
  });

  const ShikimoriOAuthConfig.fromEnvironment({
    this.redirectUri = appRedirectUri,
  }) : clientId = const String.fromEnvironment('SHIKIMORI_CLIENT_ID'),
       clientSecret = const String.fromEnvironment('SHIKIMORI_CLIENT_SECRET');

  static const authorizePath = '/oauth/authorize';
  static const tokenPath = '/oauth/token';
  static const scope = 'user_rates';

  /// Phones: the system opens the app on this link.
  static const appRedirectUri = 'iris://oauth/callback';

  /// Desktop: the system browser comes back to a server the app runs on
  /// this port. Shikimori compares redirects exactly, so the port is fixed.
  static const loopbackRedirectUri = 'http://127.0.0.1:43821/oauth/callback';

  final String clientId;
  final String clientSecret;

  /// One of the redirects registered with the application.
  final String redirectUri;

  /// What the sign-in waits for: the app's scheme, or the loopback
  /// server's origin.
  String get callbackUrlScheme {
    final uri = Uri.parse(redirectUri);
    return uri.scheme == 'http' ? uri.origin : uri.scheme;
  }

  bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
