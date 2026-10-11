/// Runs async operations one after another. A failed operation fails only
/// its own future; the next one still runs.
class SerialQueue {
  Future<void> _tail = Future<void>.value();

  Future<T> run<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (_, _) {});
    return result;
  }

  /// Completes once every operation queued so far has finished.
  Future<void> get idle => _tail;
}
