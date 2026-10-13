import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/app/di/service_locator.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/entities/watch_progress/domain/watch_progress_repository.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/app_update/domain/repositories/app_update_repository.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/auth/domain/repositories/auth_repository.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/widgets/account_listener.dart';
import 'package:iris/shared/utils/playback_runtime_initializer.dart';

Future<Widget> createApp({bool useMocks = false}) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!useMocks) {
    // Without a torrent engine the catalog, the lists and online sources
    // still work; torrents fail where they are played or downloaded.
    try {
      await PlaybackRuntimeInitializer.ensureInitialized();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Playback runtime failed to start.',
        name: 'iris.player.runtime',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
  await configureDependencies(useMocks: useMocks, reset: useMocks);

  // Watch history feeds several screens (catalog, anime page, file picker,
  // saved torrents), the Shikimori session and the list entries seen most
  // of them too, so they live above the router.
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
      BlocProvider(
        create: (_) =>
            UserRateBookCubit(repository: serviceLocator<UserRateRepository>()),
      ),
      // Once a launch: friends get new builds from the releases page.
      BlocProvider(
        create: (_) =>
            AppUpdateCubit(repository: serviceLocator<AppUpdateRepository>())
              ..check(),
      ),
    ],
    child: AccountListener(
      onChanged: (context, _) => context.read<UserRateBookCubit>().clear(),
      child: IrisApp(router: serviceLocator<GoRouter>()),
    ),
  );
}
