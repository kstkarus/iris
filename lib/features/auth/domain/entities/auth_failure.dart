/// Why signing in did not end with an account.
sealed class AuthFailure implements Exception {
  const AuthFailure();
}

/// The user closed the Shikimori page or declined; nothing to report.
final class AuthCancelled extends AuthFailure {
  const AuthCancelled();
}

/// Sign-in is not set up in this build, or not possible on this device.
final class AuthUnavailable extends AuthFailure {
  const AuthUnavailable();
}

/// The local server the browser comes back to could not start: another
/// program holds its port.
final class AuthCallbackBusy extends AuthFailure {
  const AuthCallbackBusy();
}

/// Shikimori could not be reached.
final class AuthNetworkFailure extends AuthFailure {
  const AuthNetworkFailure();
}

/// Shikimori answered, but not with a session.
final class AuthRejected extends AuthFailure {
  const AuthRejected();
}
