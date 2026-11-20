import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/features/auth/presentation/shikimori_sign_in_notice.dart';
import 'package:iris/features/settings/presentation/widgets/settings_row.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class ShikimoriAccountRow extends StatelessWidget {
  const ShikimoriAccountRow({super.key});

  static const signInButtonKey = Key('settings_shikimori_sign_in_button');
  static const signOutButtonKey = Key('settings_shikimori_sign_out_button');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<AuthCubit>();
    final state = context.watch<AuthCubit>().state;
    final status = switch (state) {
      AuthSignedIn(:final account) => SettingsStatus(
        account.nickname,
        signalColor: scheme.tertiary,
      ),
      AuthSignedOut() => SettingsStatus(
        shikimoriSignInNotice(l10n, state, canSignIn: cubit.canSignIn) ??
            l10n.settingsAccountSignedOut,
      ),
      AuthSigningIn() => SettingsStatus(l10n.settingsSigningIn),
      AuthRestoring() => SettingsStatus(l10n.settingsCheckingSession),
    };
    return SettingsAccountRow(
      title: 'Shikimori',
      status: status,
      actions: [
        if (state is AuthSignedOut && cubit.canSignIn)
          TextButton(
            key: signInButtonKey,
            onPressed: cubit.signIn,
            style: settingsActionStyle(context, primary: true),
            child: Text(l10n.commonSignIn),
          ),
        if (state is AuthSignedIn)
          TextButton(
            key: signOutButtonKey,
            onPressed: cubit.signOut,
            style: settingsActionStyle(context),
            child: Text(l10n.commonSignOut),
          ),
      ],
    );
  }
}
