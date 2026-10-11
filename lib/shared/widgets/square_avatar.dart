import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/network_image.dart';

/// A user's picture: square, framed by a hairline like the covers; a
/// picture that is missing or does not load leaves the frame empty.
class SquareAvatar extends StatelessWidget {
  const SquareAvatar({required this.url, required this.size, super.key});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final empty = ColoredBox(color: scheme.surfaceContainer);
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: url.isEmpty
              ? empty
              : Image(
                  image: networkImage(url),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => empty,
                ),
        ),
      ),
    );
  }
}
