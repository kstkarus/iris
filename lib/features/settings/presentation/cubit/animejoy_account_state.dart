enum AnimejoyAuthFailure { invalidCredentials, network, unavailable }

sealed class AnimejoyAccountState {
  const AnimejoyAccountState();
}

final class AnimejoyAccountInitial extends AnimejoyAccountState {
  const AnimejoyAccountInitial();

  @override
  bool operator ==(Object other) => other is AnimejoyAccountInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimejoyAccountChecking extends AnimejoyAccountState {
  const AnimejoyAccountChecking();

  @override
  bool operator ==(Object other) => other is AnimejoyAccountChecking;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimejoyAccountSignedOut extends AnimejoyAccountState {
  const AnimejoyAccountSignedOut({this.failure, this.expired = false});

  final AnimejoyAuthFailure? failure;
  final bool expired;

  @override
  bool operator ==(Object other) =>
      other is AnimejoyAccountSignedOut &&
      other.failure == failure &&
      other.expired == expired;

  @override
  int get hashCode => Object.hash(failure, expired);
}

final class AnimejoyAccountSigningIn extends AnimejoyAccountState {
  const AnimejoyAccountSigningIn();

  @override
  bool operator ==(Object other) => other is AnimejoyAccountSigningIn;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimejoyAccountSignedIn extends AnimejoyAccountState {
  const AnimejoyAccountSignedIn({this.unverified = false, this.failure});

  final bool unverified;
  final AnimejoyAuthFailure? failure;

  @override
  bool operator ==(Object other) =>
      other is AnimejoyAccountSignedIn &&
      other.unverified == unverified &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(unverified, failure);
}
