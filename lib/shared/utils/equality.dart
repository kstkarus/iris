/// Element-wise equality for value classes; pure Dart, so domain code can use
/// it without Flutter's `listEquals`.
bool sameList<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool sameSet<T>(Set<T> first, Set<T> second) {
  if (identical(first, second)) return true;
  return first.length == second.length && first.containsAll(second);
}

bool sameMap<K, V>(Map<K, V> first, Map<K, V> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (!second.containsKey(entry.key) || second[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
