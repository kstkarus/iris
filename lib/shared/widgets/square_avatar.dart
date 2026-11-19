import 'package:flutter/material.dart';

import 'package:iris/shared/utils/motion_duration.dart';
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
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ColoredBox(
            color: scheme.surfaceContainer,
            child: url.isEmpty
                ? null
                : Image(
                    key: ValueKey(url),
                    image: networkImage(url),
                    fit: BoxFit.cover,
                    frameBuilder: (context, child, frame, _) {
                      if (frame == null) return const SizedBox.shrink();
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 160),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (_, opacity, child) =>
                            Opacity(opacity: opacity, child: child),
                        child: child,
                      );
                    },
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    );
  }
}
