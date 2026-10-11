import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:iris/features/player/domain/entities/player_skip_segment.dart';
import 'package:iris/features/player/presentation/widgets/player_auto_hiding_offer.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// Builds an offer's button from its texts; each layout styles and places
/// its own.
typedef PlayerOfferPlate = Widget Function(String label, String? detail);

/// "Skip opening" or "Skip recap" while one plays, shown at first and then
/// with the controls; [fallback] otherwise.
class PlayerSkipSegmentOffer extends StatelessWidget {
  const PlayerSkipSegmentOffer({
    required this.segment,
    required this.controlsVisible,
    required this.plate,
    this.fallback = const SizedBox.shrink(),
    super.key,
  });

  final ValueListenable<PlayerSkipSegment?> segment;
  final ValueListenable<bool> controlsVisible;
  final PlayerOfferPlate plate;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<PlayerSkipSegment?>(
      valueListenable: segment,
      builder: (context, segment, _) {
        if (segment == null) return fallback;
        return PlayerAutoHidingOffer(
          key: ValueKey(segment),
          controlsVisible: controlsVisible,
          child: plate(
            segment.kind == PlayerSkipKind.recap
                ? l10n.playerSkipRecap
                : l10n.playerSkipOpening,
            null,
          ),
        );
      },
    );
  }
}

/// "Play next" with the next file's [title], once the file is [finishing];
/// it stays once the file has [completed].
class PlayerNextOffer extends StatelessWidget {
  const PlayerNextOffer({
    required this.finishing,
    required this.completed,
    required this.title,
    required this.controlsVisible,
    required this.plate,
    super.key,
  });

  final ValueListenable<bool> finishing;
  final ValueListenable<bool> completed;

  /// Null when there is no next file.
  final String? title;
  final ValueListenable<bool> controlsVisible;
  final PlayerOfferPlate plate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([finishing, completed]),
      builder: (context, _) {
        final title = this.title;
        final completed = this.completed.value;
        if (title == null || !(finishing.value || completed)) {
          return const SizedBox.shrink();
        }
        return PlayerAutoHidingOffer(
          controlsVisible: controlsVisible,
          // Once the file has ended there is nothing left to cover.
          pinned: completed,
          child: plate(l10n.playerPlayNext, title),
        );
      },
    );
  }
}

/// An offer's text: what it does, and under it, smaller, what it does it
/// to (the next file's title).
class PlayerOfferLabel extends StatelessWidget {
  const PlayerOfferLabel({
    required this.label,
    required this.maxWidth,
    this.detail,
    super.key,
  });

  final String label;
  final String? detail;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          if (detail != null)
            // Inherits the button's colour.
            Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: Theme.of(context).textTheme.labelSmall?.fontSize,
                fontWeight: FontWeight.w400,
              ),
            ),
        ],
      ),
    );
  }
}
