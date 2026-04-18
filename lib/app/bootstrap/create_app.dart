import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/di/service_locator.dart';
import 'package:iris/shared/utils/playback_runtime_initializer.dart';

Future<Widget> createApp({bool useMocks = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!useMocks) {
    await PlaybackRuntimeInitializer.ensureInitialized();
  }
  await configureDependencies(useMocks: useMocks, reset: useMocks);

  return IrisApp(router: serviceLocator<GoRouter>());
}
