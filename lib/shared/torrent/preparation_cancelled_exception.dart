/// Thrown when the caller stopped waiting for a torrent source before its
/// metadata arrived; the preparation has already released what it held.
class PreparationCancelledException implements Exception {
  const PreparationCancelledException();
}

/// Completes with [work], or fails with [PreparationCancelledException] when
/// [cancelled] completes first.
Future<T> unlessCancelled<T>(Future<T> work, Future<void>? cancelled) {
  if (cancelled == null) return work;
  return Future.any<T>([
    work,
    cancelled.then<T>((_) => throw const PreparationCancelledException()),
  ]);
}
