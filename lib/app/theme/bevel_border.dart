import 'package:flutter/painting.dart';

/// A square outline lit from the top left, like a key on an old desktop:
/// [light] along the top and left edges, [dark] along the bottom and right.
///
/// Swapping the two colours makes the surface look pressed in.
class BevelBorder extends OutlinedBorder {
  const BevelBorder({
    required this.light,
    required this.dark,
    this.width = 2,
    super.side,
  });

  final Color light;
  final Color dark;
  final double width;

  BevelBorder get pressed =>
      BevelBorder(light: dark, dark: light, width: width, side: side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect.deflate(width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final w = width;
    final lit = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right - w, rect.top + w)
      ..lineTo(rect.left + w, rect.top + w)
      ..lineTo(rect.left + w, rect.bottom - w)
      ..close();
    final shaded = Path()
      ..moveTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left + w, rect.bottom - w)
      ..lineTo(rect.right - w, rect.bottom - w)
      ..lineTo(rect.right - w, rect.top + w)
      ..close();
    canvas
      ..drawPath(lit, Paint()..color = light)
      ..drawPath(shaded, Paint()..color = dark);
  }

  @override
  BevelBorder copyWith({BorderSide? side}) => BevelBorder(
    light: light,
    dark: dark,
    width: width,
    side: side ?? this.side,
  );

  @override
  ShapeBorder scale(double t) => BevelBorder(
    light: light,
    dark: dark,
    width: width * t,
    side: side.scale(t),
  );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BevelBorder) {
      return BevelBorder(
        light: Color.lerp(a.light, light, t)!,
        dark: Color.lerp(a.dark, dark, t)!,
        width: a.width + (width - a.width) * t,
      );
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BevelBorder) return b.lerpFrom(this, t);
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) =>
      other is BevelBorder &&
      other.light == light &&
      other.dark == dark &&
      other.width == width &&
      other.side == side;

  @override
  int get hashCode => Object.hash(light, dark, width, side);
}
