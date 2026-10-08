/// Thrown when the caller stopped waiting for a torrent source before its
/// metadata arrived; the preparation has already released what it held.
class PreparationCancelledException implements Exception {
  const PreparationCancelledException();
}
