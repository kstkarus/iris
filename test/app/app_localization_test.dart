import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/app/app.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

void main() {
  testWidgets('shows Russian localized strings for a Russian locale', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Text(AppLocalizations.of(context).navigationCatalog),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      IrisApp(router: router, locale: const Locale('ru')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Каталог'), findsOneWidget);
  });
}
