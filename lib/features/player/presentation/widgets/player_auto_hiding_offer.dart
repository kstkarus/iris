import 'package:flutter/widgets.dart';

import 'package:iris/features/player/presentation/widgets/player_countdown.dart';

/// Pointer movement or a tap over the player.
class PlayerPointerActivity extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Shows [child] for a while when it appears, then again briefly after
/// pointer activity, like the player controls; [pinned] keeps it shown.
///
/// A [PlayerCountdownBar] in [child] shows the time left; resting the
/// pointer on it keeps it shown.
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
  Duration _showing = PlayerAutoHidingOffer.shownAtStart;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    widget.activity.addListener(_onActivity);
  }

  @override
  void dispose() {
    widget.activity.removeListener(_onActivity);
    super.dispose();
  }

  void _onActivity() {
    // Activity must not cut the first, longer showing short.
    if (_holdingAtStart) return;
    setState(() {
      _shown = true;
      _showing = PlayerAutoHidingOffer.shownOnActivity;
      _generation++;
    });
  }

  void _hide() {
    _holdingAtStart = false;
    if (mounted) setState(() => _shown = false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _shown || widget.pinned;
    return PlayerCountdown(
      duration: _shown && !widget.pinned ? _showing : null,
      afterHold: PlayerAutoHidingOffer.shownOnActivity,
      generation: _generation,
      onElapsed: _hide,
      child: IgnorePointer(
        ignoring: !visible,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: widget.child,
        ),
      ),
    );
  }
}
