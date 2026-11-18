import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/detail_layout.dart';

/// Anime-specific breakpoints and contrast for the detail cards.
abstract final class AnimeDetailsLayout {
  static const _compactActionWidth = 400;
  static const _twoColumnCardsWidth = 520;
  static const _maxFriendGridScale = 1.5;

  static bool stackCardAction(BuildContext context, double availableWidth) =>
      DetailLayout.isLargeText(context) || availableWidth < _compactActionWidth;

  static bool useFriendGrid(BuildContext context, double availableWidth) =>
      availableWidth >= _twoColumnCardsWidth &&
      MediaQuery.textScalerOf(context).scale(1) < _maxFriendGridScale;
}
