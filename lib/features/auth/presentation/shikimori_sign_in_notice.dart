import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

String? shikimoriSignInNotice(
  AppLocalizations l10n,
  AuthSignedOut state, {
  required bool canSignIn,
}) {
  if (!canSignIn) return l10n.profileSignInUnavailable;
  if (state.expired) return l10n.profileSessionExpired;
  return switch (state.failure) {
    AuthNetworkFailure() => l10n.profileSignInNetworkError,
    AuthRejected() => l10n.profileSignInRejected,
    AuthUnavailable() => l10n.profileSignInUnavailable,
    AuthCallbackBusy() => l10n.profileSignInPortBusy,
    AuthCancelled() || null => null,
  };
}
