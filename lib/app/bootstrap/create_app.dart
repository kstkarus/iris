import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/di/service_locator.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/shared/utils/playback_runtime_initializer.dart';

Future<Widget> createApp({bool useMocks = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!useMocks) {
    await PlaybackRuntimeInitializer.ensureInitialized();
  }
  await configureDependencies(useMocks: useMocks, reset: useMocks);

  // Watch history feeds several screens (catalog, anime page, file picker,
  // saved torrents), and the Shikimori session both the profile tab and the
  // anime page, so they live above the router.
  return MultiBlocProvider(
    providers: [
      BlocProvider(
        create: (_) => WatchProgressCubit(
          repository: serviceLocator<WatchProgressRepository>(),
        )..load(),
      ),
      BlocProvider(
        create: (_) =>
            AuthCubit(repository: serviceLocator<AuthRepository>())..restore(),
      ),
    ],
    child: IrisApp(router: serviceLocator<GoRouter>()),
  );
}
