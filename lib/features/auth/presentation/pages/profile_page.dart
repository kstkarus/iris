import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/domain/entities/shikimori_account.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/display_title.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';

/// The Shikimori account: an invitation to sign in, or whose list the app
/// writes to and the way out.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const signInButtonKey = Key('profile_sign_in_button');
  static const signOutButtonKey = Key('profile_sign_out_button');

  @override
  Widget build(BuildContext context) {
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    final state = context.watch<AuthCubit>().state;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, sizeClass.pageTop, margin, 0),
          child: MaxWidthBox(
            maxWidth: AdaptiveContentWidth.page,
            child: switch (state) {
              AuthRestoring() => const LoadingView(),
              AuthSigningIn() => LoadingView(
                label: AppLocalizations.of(context).profileSigningIn,
              ),
              AuthSignedOut() => _SignedOut(state: state),
              AuthSignedIn(:final account) => _Account(account: account),
            },
          ),
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

  static const _avatarSize = 72.0;

  final ShikimoriAccount account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final compact = WindowSizeClass.of(context).isCompact;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BlockRule(),
          SizedBox(height: compact ? 20 : 28),
          if (account.avatarUrl.isNotEmpty) ...[
            _Avatar(url: account.avatarUrl, size: _avatarSize),
            const SizedBox(height: 20),
          ],
          DisplayTitle(
            account.nickname,
            maxSize: compact ? 56 : 144,
            minSize: 32,
            maxLines: 1,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.profileAccountCaption.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          OutlinedButton(
            key: ProfilePage.signOutButtonKey,
            onPressed: context.read<AuthCubit>().signOut,
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
  }
}

/// Square, framed by a hairline like the covers; a picture that does not
/// load leaves the frame empty.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                ColoredBox(color: scheme.surfaceContainer),
          ),
        ),
      ),
    );
  }
}
