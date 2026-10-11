import 'package:flutter/widgets.dart';

/// [duration], or none when the system asks for less motion.
Duration motionDuration(BuildContext context, Duration duration) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
