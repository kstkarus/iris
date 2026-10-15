import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/network_image.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';

/// Cover art in the 2:3 poster ratio, framed by a hairline so light covers
/// keep their edge on a light background. A cover on its way is
/// [PixelNoise] and develops out of it; a missing one is an empty frame.
class PosterImage extends StatelessWidget {
  const PosterImage({required this.url, this.fallback, super.key});

  static const aspectRatio = 2 / 3;

  final String url;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: url.isEmpty
            ? fallback ?? ColoredBox(color: scheme.surfaceContainer)
            : Image(
                image: networkImage(url),
                fit: BoxFit.cover,
                frameBuilder: (context, child, frame, synchronous) {
                  if (synchronous) return child;
                  return DitherSwitcher(
                    expand: true,
                    child: frame == null
                        ? const PixelNoise(key: ValueKey('noise'))
                        : KeyedSubtree(
                            key: const ValueKey('cover'),
                            child: child,
                          ),
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    fallback ?? ColoredBox(color: scheme.surfaceContainer),
              ),
      ),
    );
  }
}
