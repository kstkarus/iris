abstract interface class AnimejoyAccountRepository {
  /// Changes whenever work started under the previous account must be discarded.
  int get generation;

  /// Emits true after sign-in and false when the session is cleared.
  Stream<bool> get sessionChanges;

  /// Reads the local session without contacting AnimeJoy.
  Future<bool> hasSavedSession();

  Future<bool> restore();

  Future<void> signIn({required String login, required String password});

  Future<void> signOut();
}

class AnimejoySignInRejected implements Exception {
  const AnimejoySignInRejected();
}

class AnimejoySessionChanged implements Exception {
  const AnimejoySessionChanged();
}
