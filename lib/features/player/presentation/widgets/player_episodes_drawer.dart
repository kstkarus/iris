import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

/// The episodes over the right side of the immersive player; a click beside
/// it closes it. While open it is modal: focus moves into it, Tab stays in
/// it, and screen readers see only it.
class PlayerEpisodesDrawer extends StatelessWidget {
  const PlayerEpisodesDrawer({
    required this.onClose,
    required this.builder,
    this.caption,
    super.key,
  });

  static const _minWidth = 320.0;
  static const _maxWidth = 420.0;

  /// The list fades out under the header over this height.
  static const _fadeHeight = 24.0;

  final VoidCallback onClose;
  final PlayerEpisodesBuilder builder;

  /// Context under the title, e.g. the release and how many files it has.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth * 0.32).clamp(_minWidth, _maxWidth);
        final drawer = Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              key: const Key('player_episodes_barrier'),
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const ColoredBox(color: Colors.black38),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) => Transform.translate(
                offset: Offset((1 - value) * 48, 0),
                child: Opacity(opacity: value, child: child),
              ),
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    key: const Key('player_episodes_drawer'),
                    width: width,
                    height: double.infinity,
                    child: _Panel(
                      caption: caption,
                      onClose: onClose,
                      list: builder(context, onClose),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
        // Keys the drawer leaves alone, such as Escape, still reach the
        // player's shortcuts above this scope.
        return BlockSemantics(
          child: FocusScope(autofocus: true, child: drawer),
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.caption,
    required this.onClose,
    required this.list,
  });

  final String? caption;
  final VoidCallback onClose;
  final Widget list;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final caption = this.caption;
    return ClipRect(
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC121212),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 12, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.playerEpisodesTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (caption != null && caption.isNotEmpty)
                              Text(
                                caption,
                                key: const Key('player_episodes_caption'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white60,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('player_episodes_close_button'),
                      color: Colors.white,
                      icon: PixelIcon(
                        PixelGlyph.close,
                        size: 18,
                        semanticLabel: l10n.playerCloseEpisodes,
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              Expanded(
                // Cards scroll out under the header instead of being cut.
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [Colors.transparent, Colors.white],
                    stops: [
                      0,
                      bounds.height <= 0
                          ? 0
                          : (PlayerEpisodesDrawer._fadeHeight / bounds.height)
                                .clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds),
                  child: list,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
