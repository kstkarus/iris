import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/features/auth/presentation/shikimori_sign_in_notice.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/widgets/profile_header.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/features/settings/presentation/widgets/settings_icon_button.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The Shikimori account and its list, or an invitation to sign in.
///
/// Signed in, it needs a `UserListCubit` showing the account's list and
/// a `FriendsCubit` with the account's friends.
class ProfilePage extends StatelessWidget {
  const ProfilePage({
    required this.onOpenAnime,
    required this.onOpenFriend,
    required this.onBrowseCatalog,
    required this.onOpenSettings,
    super.key,
  });

  static const signInButtonKey = Key('profile_sign_in_button');
  static const settingsButtonKey = Key('profile_settings_button');

  final ValueChanged<UserListEntry> onOpenAnime;
  final ValueChanged<Friend> onOpenFriend;
  final VoidCallback onBrowseCatalog;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final compact = WindowSizeClass.of(context).isCompact;
    final state = context.watch<AuthCubit>().state;
    final settings = compact
        ? SizedBox(
            height: ProfileHeader.compactRowHeight,
            child: Center(
              widthFactor: 1,
              child: SettingsIconButton(
                key: settingsButtonKey,
                onPressed: onOpenSettings,
              ),
            ),
          )
        : null;
    final (Object key, Widget view) = switch (state) {
      AuthRestoring() => ('restoring', const LoadingView()),
      AuthSigningIn() => (
        'signing_in',
        LoadingView(
          label: l10n.profileSigningIn,
          details: [l10n.profileSigningInHint],
        ),
      ),
      AuthSignedOut() => ('signed_out', _SignedOut(state: state)),
      AuthSignedIn(:final account) => (
        'signed_in_${account.id}',
        UserListView(
          header: ProfileHeader(
            nickname: account.nickname,
            avatarUrl: account.avatarUrl,
            trailing: settings,
          ),
          onOpen: onOpenAnime,
          onOpenFriend: onOpenFriend,
          onBrowseCatalog: onBrowseCatalog,
          mine: true,
        ),
      ),
    };
    final switcher = DitherSwitcher(
      expand: true,
      duration: const Duration(milliseconds: 300),
      child: KeyedSubtree(key: ValueKey(key), child: view),
    );
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: settings != null
              ? Stack(
                  fit: StackFit.passthrough,
                  children: [
                    switcher,
                    if (state is! AuthSignedIn)
                      PositionedDirectional(top: 0, end: 0, child: settings),
                  ],
                )
              : switcher,
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
    final message =
        shikimoriSignInNotice(l10n, state, canSignIn: canSignIn) ??
        l10n.profileSignInMessage;
    return MessageView(
      icon: PixelIcon(
        PixelGlyph.shikimori,
        size: 42,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: l10n.profileSignInTitle,
      message: message,
      action: FilledButton(
        key: ProfilePage.signInButtonKey,
        onPressed: canSignIn ? cubit.signIn : null,
        child: Text(l10n.commonSignIn),
      ),
    );
  }
}
