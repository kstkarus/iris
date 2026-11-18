import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'package:iris/features/player/presentation/widgets/player_colors.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';

/// The episodes over the right side of the immersive player; a click beside
/// it closes it. While [open] it is modal: focus moves into it, Tab stays in
/// it, and screen readers see only it.
class PlayerEpisodesDrawer extends StatefulWidget {
  const PlayerEpisodesDrawer({
    required this.onClose,
    required this.builder,
    this.open = true,
    this.onExited,
    this.caption,
    super.key,
  });

  static const _minWidth = 320.0;
  static const _maxWidth = 420.0;
  static const _duration = Duration(milliseconds: 220);

  final bool open;
  final VoidCallback onClose;
  final VoidCallback? onExited;
  final PlayerEpisodesBuilder builder;

  /// Context under the title, e.g. the release and how many files it has.
  final String? caption;

  @override
  State<PlayerEpisodesDrawer> createState() => _PlayerEpisodesDrawerState();
}

class _PlayerEpisodesDrawerState extends State<PlayerEpisodesDrawer>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);
  late final _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  bool _exitScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_onAnimationStatus);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || widget.open) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      if (_exitScheduled) return;
      _exitScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _exitScheduled = false;
        if (mounted && !widget.open) widget.onExited?.call();
      });
      return;
    }
    widget.onExited?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = motionDuration(
      context,
      PlayerEpisodesDrawer._duration,
    );
    if (widget.open && _controller.status == AnimationStatus.dismissed) {
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodesDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.open == oldWidget.open) return;
    _controller.duration = motionDuration(
      context,
      PlayerEpisodesDrawer._duration,
    );
    if (widget.open) {
      _exitScheduled = false;
      if (_controller.duration == Duration.zero) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    } else {
      if (_controller.duration == Duration.zero) {
        _controller.value = 0;
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth * 0.32).clamp(
          PlayerEpisodesDrawer._minWidth,
          PlayerEpisodesDrawer._maxWidth,
        );
        final drawer = IgnorePointer(
          ignoring: !widget.open,
          child: AnimatedBuilder(
            animation: _curve,
            builder: (context, panel) => Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  key: const Key('player_episodes_barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onClose,
                  child: ColoredBox(
                    color: Colors.black38.withValues(
                      alpha: 0.38 * _curve.value,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset((1 - _curve.value) * 48, 0),
                  child: Opacity(opacity: _curve.value, child: panel),
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                // Clear of a camera cutout at the side of a phone.
                padding:
                    const EdgeInsets.all(16) +
                    MediaQuery.paddingOf(context).copyWith(left: 0, bottom: 0),
                child: SizedBox(
                  key: const Key('player_episodes_drawer'),
                  width: width,
                  height: double.infinity,
                  child: _Panel(
                    caption: widget.caption,
                    onClose: widget.onClose,
                    list: widget.builder(context, widget.onClose),
                  ),
                ),
              ),
            ),
          ),
        );
        // Keys the drawer leaves alone, such as Escape, still reach the
        // player's shortcuts above this scope.
        return BlockSemantics(
          blocking: widget.open,
          child: FocusScope(autofocus: widget.open, child: drawer),
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
            color: playerPlateBackground,
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.playerEpisodesTitle,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontFamily: DetailLayout.sansFont,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: playerPlateText,
                              ),
                            ),
                            if (caption != null && caption.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              PixelSeparatedText(
                                caption,
                                key: const Key('player_episodes_caption'),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily: DetailLayout.sansFont,
                                  fontSize: 12.5,
                                  color: playerPlateSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      key: const Key('player_episodes_close_button'),
                      color: playerPlateText,
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
              const Divider(height: 1, thickness: 1, color: Colors.white12),
              Expanded(child: list),
            ],
          ),
        ),
      ),
    );
  }
}
