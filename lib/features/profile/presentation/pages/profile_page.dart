import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/widgets/profile_header.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The Shikimori account: an invitation to sign in, or whose list the app
/// writes to, the way out and the list itself by status.
///
/// Signed in, it needs a `UserListCubit` showing the account's list and
/// a `FriendsCubit` with the account's friends.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.onOpenAnime,
    required this.onOpenFriend,
    required this.onBrowseCatalog,
    super.key,
  });

  static const signInButtonKey = Key('profile_sign_in_button');
  static const signOutButtonKey = Key('profile_sign_out_button');

  final ValueChanged<UserListEntry> onOpenAnime;
  final ValueChanged<Friend> onOpenFriend;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: switch (state) {
            AuthRestoring() => const LoadingView(),
            AuthSigningIn() => LoadingView(
              label: AppLocalizations.of(context).profileSigningIn,
              details: [AppLocalizations.of(context).profileSigningInHint],
            ),
            AuthSignedOut() => _SignedOut(state: state),
            AuthSignedIn(:final account) => UserListView(
              header: _Account(account: account),
              onOpen: onOpenAnime,
              onOpenFriend: onOpenFriend,
              onBrowseCatalog: onBrowseCatalog,
              mine: true,
            ),
          },
        ),
      ),
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({required this.state});

  final AuthSignedOut state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<AuthCubit>();
    final canSignIn = cubit.canSignIn;
    final message = !canSignIn
        ? l10n.profileSignInUnavailable
        : state.expired
        ? l10n.profileSessionExpired
        : switch (state.failure) {
            AuthNetworkFailure() => l10n.profileSignInNetworkError,
            AuthRejected() => l10n.profileSignInRejected,
            AuthUnavailable() => l10n.profileSignInUnavailable,
            AuthCallbackBusy() => l10n.profileSignInPortBusy,
            AuthCancelled() || null => l10n.profileSignInMessage,
          };
    return MessageView(
      title: l10n.profileSignInTitle,
      message: message,
      action: FilledButton(
        key: ProfilePage.signInButtonKey,
        onPressed: canSignIn ? cubit.signIn : null,
        child: Text(l10n.profileSignInButton),
      ),
    );
  }
}

class _Account extends StatelessWidget {
  const _Account({required this.account});

  final ShikimoriAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ProfileHeader(
      nickname: account.nickname,
      avatarUrl: account.avatarUrl,
      // Rare, and costly to undo (signing in again goes through the
      // browser): a quiet grey button out of the way of the list.
      trailing: TextButton(
        key: ProfilePage.signOutButtonKey,
        style: TextButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: context.read<AuthCubit>().signOut,
        child: Text(l10n.profileSignOut),
      ),
    );
  }
}
