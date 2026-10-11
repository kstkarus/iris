import 'package:flutter/services.dart';

/// What the player page asks of the device's screen while it is open.
abstract interface class PlayerScreenMode {
  /// The page opened, or the app came back to it.
  Future<void> enter();

  /// The page is leaving; safe to call more than once.
  Future<void> leave();
}

/// Leaves the screen as it is: desktop windows switch full screen from the
/// player's own controls.
class NoPlayerScreenMode implements PlayerScreenMode {
  const NoPlayerScreenMode();

  @override
  Future<void> enter() async {}

  @override
  Future<void> leave() async {}
}

/// Phones and tablets play in landscape, either way round, with the system
/// bars hidden until swiped in. Leaving goes back to the app's edge-to-edge
/// layout and free rotation; media_kit's own exit sets the bars to manual,
/// which breaks edge-to-edge on Android 15 and later.
class PhonePlayerScreenMode implements PlayerScreenMode {
  const PhonePlayerScreenMode();

  @override
  Future<void> enter() async {
    await SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Future<void> leave() async {
    await SystemChrome.setPreferredOrientations(const []);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
}
