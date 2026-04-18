import 'package:flutter/widgets.dart';

import 'package:iris/app/bootstrap/create_app.dart';

export 'package:iris/app/bootstrap/create_app.dart' show createApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await createApp());
}
