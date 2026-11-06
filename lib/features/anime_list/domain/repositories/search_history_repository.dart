abstract interface class SearchHistoryRepository {
  List<String> read();
  Future<void> save(List<String> queries);
}
