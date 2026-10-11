/// [items] with the ones the user [watched] first, keeping the order inside
/// both groups.
List<T> watchedFirst<T>(List<T> items, bool Function(T item) watched) => [
  ...items.where(watched),
  ...items.where((item) => !watched(item)),
];
