import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/shared/network/shikimori_oauth_config.dart';

/// Shows the sign-in page and returns the redirect it ends on.
abstract interface class WebAuthenticator {
  /// Throws [AuthCancelled] when the user closes the page, and
  /// [AuthUnavailable] when the device has no way to show it.
  Future<Uri> authenticate(Uri url);
}

/// A browser tab on Android, the system sheet on iOS, a WebView2 window on
/// Windows; each hands back the `iris://` redirect.
class FlutterWebAuthenticator implements WebAuthenticator {
  const FlutterWebAuthenticator();

  @override
  Future<Uri> authenticate(Uri url) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: ShikimoriOAuthConfig.callbackScheme,
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') throw const AuthCancelled();
      throw const AuthUnavailable();
    } on StateError {
      // Windows without the WebView2 runtime.
      throw const AuthUnavailable();
    }
  }
}
