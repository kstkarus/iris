import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';

/// A [MaterialApp] with the app's localizations, pinned to [locale].
Widget testApp(
  Widget home, {
  Locale locale = const Locale('en'),
  ThemeData? theme,
  Key? key,
}) {
  return MaterialApp(
    key: key,
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: home,
  );
}

/// [testApp] for a router.
Widget testRouterApp(
  RouterConfig<Object> routerConfig, {
  Locale locale = const Locale('en'),
}) {
  return MaterialApp.router(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: routerConfig,
  );
}
