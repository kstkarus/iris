import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';

/// Shows the sign-in page and returns the redirect it ends on.
abstract interface class WebAuthenticator {
  /// Throws [AuthCancelled] when the user closes the page, and
  /// [AuthUnavailable] when the device has no way to show it.
  Future<Uri> authenticate(Uri url);
}

/// A browser tab on Android and the system sheet on iOS, which hand back
/// the `iris://` redirect; the default browser on Windows and Linux, which
/// comes back to a local server at [callbackUrlScheme].
///
/// On desktop the plugin stops waiting once the app's window is active
/// again, which is how a sign-in left in the browser is cancelled.
class FlutterWebAuthenticator implements WebAuthenticator {
  const FlutterWebAuthenticator({required this.callbackUrlScheme});

  final String callbackUrlScheme;

  @override
  Future<Uri> authenticate(Uri url) async {
    try {
      final result = await FlutterWebAuth2.authenticate(
        url: url.toString(),
        callbackUrlScheme: callbackUrlScheme,
        options: FlutterWebAuth2Options(
          useWebview: false,
          landingPageHtml: asciiHtml(_landingPage),
        ),
      );
      return Uri.parse(result);
    } on PlatformException catch (error) {
      if (error.code == 'CANCELED') throw const AuthCancelled();
      throw const AuthUnavailable();
    } on SocketException {
      // Another program holds the loopback port.
      throw const AuthCallbackBusy();
    }
  }
}

/// [html] with every character past ASCII as a numeric reference.
///
/// The plugin's server sends the page as `text/html` without a charset,
/// so Dart encodes it as Latin-1, and a letter outside it fails the
/// response: the browser would wait for it forever.
@visibleForTesting
String asciiHtml(String html) => String.fromCharCodes(
  html.runes.expand((rune) => rune < 0x80 ? [rune] : '&#$rune;'.codeUnits),
);

/// What the browser shows once it has handed the redirect to the app.
const _landingPage = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iris</title>
  <style>
    html, body { margin: 0; height: 100%; background: #111; color: #eee; }
    main {
      display: flex; flex-direction: column; justify-content: center;
      height: 100%; padding: 0 10vw;
      font-family: ui-monospace, Consolas, monospace; line-height: 1.6;
    }
  </style>
</head>
<body>
  <main>
    <p>&gt;&gt; iris</p>
    <p>Можно вернуться в приложение и закрыть вкладку.<br>
    You can go back to the app and close this tab.</p>
  </main>
</body>
</html>
''';
