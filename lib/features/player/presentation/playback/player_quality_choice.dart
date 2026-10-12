import 'package:iris/shared/utils/equality.dart';

/// The qualities the playing file is offered in, and which one is chosen.
class PlayerQualityChoice {
  const PlayerQualityChoice({required this.offered, required this.selected});

  /// Picture heights, tallest first.
  final List<int> offered;

  /// One of [offered], or null for "Auto" (the tallest).
  final int? selected;

  @override
  bool operator ==(Object other) =>
      other is PlayerQualityChoice &&
      other.selected == selected &&
      sameList(other.offered, offered);

  @override
  int get hashCode => Object.hash(selected, Object.hashAll(offered));
}
