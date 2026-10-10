import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/widgets.dart';

import 'package:iris/app/bootstrap/create_app.dart';

export 'package:iris/app/bootstrap/create_app.dart' show createApp;

Future<void> main(List<String> args) async {
  // On Windows the sign-in window's title bar runs this entry point too.
  if (runWebViewTitleBarWidget(args)) return;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await createApp());
}
