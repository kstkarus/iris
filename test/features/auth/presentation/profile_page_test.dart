import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/pages/profile_page.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import 'auth_test_doubles.dart';

void main() {
  Future<AuthCubit> pumpPage(
    WidgetTester tester,
    FakeAuthRepository repository,
  ) async {
    final cubit = AuthCubit(repository: repository);
    await cubit.restore();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(value: cubit, child: const ProfilePage()),
      ),
    );
    await tester.pump();
    return cubit;
  }

  FilledButton signInButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(ProfilePage.signInButtonKey));

  testWidgets('signed out, it invites to sign in', (tester) async {
    final repository = FakeAuthRepository()..signInGate = Completer();
    await pumpPage(tester, repository);

    expect(find.text('Your Shikimori list'), findsOneWidget);
    expect(signInButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(ProfilePage.signInButtonKey));
    await tester.pump();
    expect(find.text('Waiting for Shikimori'), findsOneWidget);

    repository.signInGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('kstk'), findsOneWidget);
  });

  testWidgets('without sign-in set up, the button is off and says why', (
    tester,
  ) async {
    await pumpPage(tester, FakeAuthRepository(canSignIn: false));

    expect(find.text('Sign-in is not set up in this build.'), findsOneWidget);
    expect(signInButton(tester).onPressed, isNull);
  });

  testWidgets('a failed sign-in says so in place of the invitation', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..failure = const AuthNetworkFailure();
    await pumpPage(tester, repository);

    await tester.tap(find.byKey(ProfilePage.signInButtonKey));
    await tester.pump();
    await tester.pump();

    expect(find.text('Shikimori did not respond. Try again.'), findsOneWidget);
  });

  testWidgets('signed in, it names the account and signs out', (tester) async {
    final repository = FakeAuthRepository(restored: testAccount);
    await pumpPage(tester, repository);

    expect(find.text('kstk'), findsOneWidget);
    expect(find.text('SHIKIMORI ACCOUNT'), findsOneWidget);

    await tester.tap(find.byKey(ProfilePage.signOutButtonKey));
    await tester.pump();
    await tester.pump();

    expect(repository.signOuts, 1);
    expect(find.byKey(ProfilePage.signInButtonKey), findsOneWidget);
  });

  testWidgets('a session Shikimori ended asks to sign in again', (
    tester,
  ) async {
    final repository = FakeAuthRepository(restored: testAccount);
    await pumpPage(tester, repository);

    repository.expire();
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Shikimori ended the session. Sign in again.'),
      findsOneWidget,
    );
  });
}
