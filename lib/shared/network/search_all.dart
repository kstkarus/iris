/// Runs [search] for every query at once and returns, in query order, the
/// items [keep] accepts. A query that fails does not hide what the others
/// found: its failure is thrown only when nothing was kept, so it reads as
/// an error rather than "not there". Of several failures, the first query's
/// is thrown.
Future<List<T>> searchAll<T>(
  Iterable<String> queries,
  Future<List<T>> Function(String query) search, {
  required bool Function(T item) keep,
}) async {
  final results = await Future.wait(
    queries.map((query) async {
      try {
        return (items: await search(query), error: null);
      } on Object catch (error) {
        return (items: <T>[], error: error);
      }
    }),
  );
  final kept = [
    for (final result in results)
      for (final item in result.items)
        if (keep(item)) item,
  ];
  if (kept.isEmpty) {
    for (final result in results) {
      if (result.error case final error?) throw error;
    }
  }
  return kept;
}
