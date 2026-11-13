import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/widgets/download_announcements.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class IrisApp extends StatelessWidget {
  const IrisApp({
    required this.router,
    required this.downloadsRepository,
    this.locale,
    super.key,
  });

  final GoRouter router;
  final DownloadsRepository downloadsRepository;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: buildAppTheme(),
      darkTheme: buildAppTheme(brightness: Brightness.dark),
      routerConfig: router,
      builder: (context, child) =>
          DownloadAnnouncements(repository: downloadsRepository, child: child!),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}
