import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';

/// While [enabled], [child] shows as pixel noise in the shape of its own
/// layout: give it stand-in data and every line, picture and button
/// becomes a noise block where the real one will be. When it turns off,
/// the content develops out of the noise cell by cell.
///
/// Screen readers hear [semanticLabel] instead of the stand-in data.
/// Wrap parts that are already real, such as section labels, in
/// [Skeleton.keep].
class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    required this.enabled,
    required this.child,
    this.semanticLabel,
    super.key,
  });

  final bool enabled;
  final Widget child;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: enabled ? semanticLabel : null,
      child: ExcludeSemantics(
        excluding: enabled,
        child: Skeletonizer(
          enabled: enabled,
          effect: PixelNoiseEffect.of(context),
          textBoneBorderRadius: const TextBoneBorderRadius(BorderRadius.zero),
          enableSwitchAnimation: animate,
          switchAnimationConfig: const SwitchAnimationConfig(
            duration: DitherTransition.duration,
            transitionBuilder: DitherTransition.transition,
            layoutBuilder: DitherTransition.layout,
          ),
          child: child,
        ),
      ),
    );
  }
}
