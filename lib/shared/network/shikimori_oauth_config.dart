/// The app's Shikimori OAuth application.
///
/// The id and secret come from a local, git-ignored file passed at build
/// time (`--dart-define-from-file=config/shikimori.json`, see README); a
/// build without it runs, only without sign-in.
class ShikimoriOAuthConfig {
  const ShikimoriOAuthConfig({
    required this.clientId,
    required this.clientSecret,
  });

  const ShikimoriOAuthConfig.fromEnvironment()
    : clientId = const String.fromEnvironment('SHIKIMORI_CLIENT_ID'),
      clientSecret = const String.fromEnvironment('SHIKIMORI_CLIENT_SECRET');

  static const authorizePath = '/oauth/authorize';
  static const tokenPath = '/oauth/token';

  /// Registered with the application; the platform hands it back to the app.
  static const redirectUri = 'iris://oauth/callback';
  static const callbackScheme = 'iris';
  static const scope = 'user_rates';

  final String clientId;
  final String clientSecret;

  bool get isConfigured => clientId.isNotEmpty && clientSecret.isNotEmpty;
}
