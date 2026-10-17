enum AppUpdateFailureKind {
  network,
  invalidFile,
  storage,
  install,
  permission,
  cancelled,
}

final class AppUpdateFailure implements Exception {
  const AppUpdateFailure(this.kind);

  final AppUpdateFailureKind kind;
}
