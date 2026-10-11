/// The value of [values] named [rawValue], or [fallback] when it is null or
/// unknown. A non-string [rawValue] throws, so a corrupt record is noticed.
T enumByName<T extends Enum>(List<T> values, Object? rawValue, T fallback) {
  final name = rawValue as String?;
  if (name == null) return fallback;
  return values.asNameMap()[name] ?? fallback;
}
