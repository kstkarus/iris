import 'dart:async';

import 'package:flutter/widgets.dart';

/// Pointer movement or a tap over the player.
class PlayerPointerActivity extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Shows [child] for a while when it appears, then again briefly after
/// pointer activity, like the player controls; [pinned] keeps it shown.
class PlayerAutoHidingOffer extends StatefulWidget {
  const PlayerAutoHidingOffer({
    required this.activity,
    required this.child,
    this.pinned = false,
    super.key,
  });

  static const shownAtStart = Duration(seconds: 8);
  static const shownOnActivity = Duration(seconds: 3);

  final Listenable activity;
  final bool pinned;
  final Widget child;

  @override
  State<PlayerAutoHidingOffer> createState() => _PlayerAutoHidingOfferState();
}

class _PlayerAutoHidingOfferState extends State<PlayerAutoHidingOffer> {
  bool _shown = true;
  bool _holdingAtStart = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    widget.activity.addListener(_onActivity);
    _hideAfter(PlayerAutoHidingOffer.shownAtStart);
  }

  @override
  void dispose() {
    widget.activity.removeListener(_onActivity);
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onActivity() {
    // Activity must not cut the first, longer showing short.
    if (_holdingAtStart) return;
    setState(() => _shown = true);
    _hideAfter(PlayerAutoHidingOffer.shownOnActivity);
  }

  void _hideAfter(Duration duration) {
    _hideTimer?.cancel();
    _hideTimer = Timer(duration, () {
      _holdingAtStart = false;
      if (mounted) setState(() => _shown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _shown || widget.pinned;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: widget.child,
      ),
    );
  }
}
