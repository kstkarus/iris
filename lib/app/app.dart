import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/cubit/download_activity_cubit.dart';
import 'package:iris/features/downloads/presentation/widgets/download_announcements.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/window/windows_title_bar_theme.dart';

class IrisApp extends StatefulWidget {
  const IrisApp({
    required this.router,
    required this.downloadsRepository,
    this.themeMode = ThemeMode.system,
    this.locale,
    super.key,
  });

  final GoRouter router;
  final DownloadsRepository downloadsRepository;
  final ThemeMode themeMode;
  final Locale? locale;

  @override
  State<IrisApp> createState() => _IrisAppState();
}

class _IrisAppState extends State<IrisApp> {
  final _titleBarTheme = WindowsTitleBarTheme();
  final _downloadActivity = DownloadActivityCubit();

  @override
  void dispose() {
    unawaited(_downloadActivity.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: buildAppTheme(disableAnimations: disableAnimations),
      darkTheme: buildAppTheme(
        brightness: Brightness.dark,
        disableAnimations: disableAnimations,
      ),
      themeMode: widget.themeMode,
      themeAnimationDuration: disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      routerConfig: widget.router,
      builder: (context, child) {
        _titleBarTheme.setAppTheme(Theme.of(context).colorScheme);
        return RepositoryProvider.value(
          value: _titleBarTheme,
          child: BlocProvider.value(
            value: _downloadActivity,
            child: DownloadAnnouncements(
              repository: widget.downloadsRepository,
              activityCubit: _downloadActivity,
              child: child!,
            ),
          ),
        );
      },
      locale: widget.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
