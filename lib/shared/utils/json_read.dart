/// Lenient readers for decoded JSON: a missing or mistyped value falls back
/// instead of failing the whole object.
library;

Map<Object?, Object?> jsonMap(Object? value) => value is Map ? value : const {};

String jsonString(Object? value) => value is String ? value : '';

num jsonNum(Object? value) => value is num ? value : 0;

int jsonInt(Object? value) => value is num ? value.toInt() : 0;

/// Also reads an integer written as a string; null when there is none.
int? jsonIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}
