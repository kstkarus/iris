import 'package:flutter_test/flutter_test.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'package:iris/shared/haptics/app_haptics.dart';

List<HapticsType> recordHaptics() {
  final effects = <HapticsType>[];
  AppHaptics.debugOverride = (
    canVibrate: () async => true,
    vibrate: (type) async => effects.add(type),
  );
  addTearDown(() => AppHaptics.debugOverride = null);
  return effects;
}
