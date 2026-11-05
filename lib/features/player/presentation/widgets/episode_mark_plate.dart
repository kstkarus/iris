import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/player/presentation/cubit/episode_mark_cubit.dart';
import 'package:iris/features/player/presentation/widgets/player_colors.dart';
import 'package:iris/features/player/presentation/widgets/player_countdown.dart';
import 'package:iris/features/player/presentation/widgets/player_wait_indicator.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

const _background = Color(0xE60B0C0E);
const _border = Color(0xFF3A3D42);
const _text = Color(0xFFF2F2F0);
const _secondary = Color(0xFFA8AAB0);
const _warning = Color(0xFFFFD93B);

class EpisodeMarkPlate extends StatefulWidget {
  const EpisodeMarkPlate({
    required this.cubit,
    required this.controlsVisible,
    super.key,
  });

  final EpisodeMarkCubit cubit;
  final ValueListenable<bool> controlsVisible;

  @override
  State<EpisodeMarkPlate> createState() => _EpisodeMarkPlateState();
}

class _EpisodeMarkPlateState extends State<EpisodeMarkPlate> {
  bool _open = true;
  bool _intro = true;
  bool _engaged = false;
  int _version = 0;
  int _collapseVersion = 0;

  void _newState(BuildContext context, EpisodeMarkState state) {
    if (state is EpisodeMarkIdle) return;
    setState(() {
      _open = true;
      _intro = true;
      _engaged = false;
      _version++;
      _collapseVersion++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.cubit.revisions,
      builder: (context, _, _) =>
          BlocConsumer<EpisodeMarkCubit, EpisodeMarkState>(
            bloc: widget.cubit,
            listener: _newState,
            builder: (context, state) {
              if (state is EpisodeMarkIdle) return const SizedBox.shrink();
              final loading = state is EpisodeMarkSaving;
              final attention =
                  state is EpisodeMarkFailed ||
                  state is EpisodeMarkQueued ||
                  state is EpisodeMarkConflict ||
                  state is EpisodeMarkOffered;
              return ValueListenableBuilder<bool>(
                valueListenable: widget.controlsVisible,
                builder: (context, controlsVisible, child) {
                  final visible =
                      attention ||
                      loading ||
                      _intro ||
                      controlsVisible ||
                      _open;
                  return IgnorePointer(
                    ignoring: !visible,
                    child: AnimatedOpacity(
                      key: const Key('player_mark_visibility'),
                      opacity: visible ? 1 : 0,
                      duration: motionDuration(
                        context,
                        const Duration(milliseconds: 200),
                      ),
                      child: child,
                    ),
                  );
                },
                child: LayoutBuilder(
                  builder: (context, constraints) => Align(
                    alignment: Alignment.topLeft,
                    heightFactor: 1,
                    child: PlayerCountdown(
                      key: ValueKey('mark_visible_$_version'),
                      running: TickerMode.valuesOf(context).enabled,
                      duration: attention || loading || _engaged || !_intro
                          ? null
                          : const Duration(seconds: 8),
                      onElapsed: () => setState(() => _intro = false),
                      child: PlayerCountdownBar(
                        color: _open ? Colors.transparent : _secondary,
                        child: PlayerCountdown(
                          key: ValueKey('mark_collapse_$_collapseVersion'),
                          running: TickerMode.valuesOf(context).enabled,
                          duration: _open && !loading
                              ? Duration(
                                  seconds: state is EpisodeMarkOffered
                                      ? 15
                                      : attention
                                      ? 10
                                      : 5,
                                )
                              : null,
                          onElapsed: () {
                            if (state is EpisodeMarkOffered) {
                              widget.cubit.dismiss();
                            } else {
                              setState(() {
                                _open = false;
                                _engaged = false;
                              });
                            }
                          },
                          child: PlayerCountdownBar(
                            color: _secondary,
                            child: _plate(context, state, constraints.maxWidth),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _plate(BuildContext context, EpisodeMarkState state, double maxWidth) {
    final l10n = AppLocalizations.of(context);
    final accent = playerAccentColor(Theme.of(context).colorScheme);
    final short = maxWidth < MediaQuery.textScalerOf(context).scale(270);
    final loading = state is EpisodeMarkSaving;
    final error =
        state is EpisodeMarkFailed ||
        state is EpisodeMarkConflict ||
        state is EpisodeMarkQueued && state.failed;
    final episode = switch (state) {
      EpisodeMarkOffered(:final episode) ||
      EpisodeMarkSaving(:final episode) ||
      EpisodeMarkDone(:final episode) ||
      EpisodeMarkUndone(:final episode) ||
      EpisodeMarkRecorded(:final episode) ||
      EpisodeMarkFailed(:final episode) ||
      EpisodeMarkQueued(:final episode) ||
      EpisodeMarkConflict(:final episode) => episode,
      EpisodeMarkIdle() => 0,
    };
    final marked =
        state is EpisodeMarkDone ||
        state is EpisodeMarkRecorded ||
        state is EpisodeMarkSaving && state.action == EpisodeMarkAction.undo;
    final unmarked =
        state is EpisodeMarkUndone ||
        state is EpisodeMarkSaving && state.action == EpisodeMarkAction.restore;
    final label = switch (state) {
      EpisodeMarkOffered() => l10n.playerMarkOffer(episode),
      EpisodeMarkSaving(action: EpisodeMarkAction.mark) =>
        l10n.playerMarkSaving,
      EpisodeMarkSaving(action: EpisodeMarkAction.undo) =>
        l10n.playerUnmarkSaving,
      EpisodeMarkSaving(action: EpisodeMarkAction.restore) =>
        short ? l10n.playerMarkShortRestoreSaving : l10n.playerRestoreSaving,
      EpisodeMarkDone() || EpisodeMarkRecorded() =>
        short ? l10n.playerMarkShortMarked : l10n.playerMarked(episode),
      EpisodeMarkUndone() =>
        short ? l10n.playerMarkShortUnset : l10n.playerMarkUnset(episode),
      EpisodeMarkFailed(action: EpisodeMarkAction.mark) =>
        short ? l10n.playerMarkShortFailed : l10n.playerMarkFailed(episode),
      EpisodeMarkFailed(action: EpisodeMarkAction.undo) =>
        l10n.playerUnmarkFailed,
      EpisodeMarkFailed(action: EpisodeMarkAction.restore) =>
        l10n.playerRestoreFailed,
      EpisodeMarkQueued(failed: true) =>
        short
            ? l10n.playerMarkShortSyncFailed
            : l10n.playerMarkSyncFailed(episode),
      EpisodeMarkQueued() =>
        short ? l10n.playerMarkShortWaiting : l10n.playerMarkWaiting(episode),
      EpisodeMarkConflict() =>
        short ? l10n.playerMarkShortConflict : l10n.playerMarkConflict,
      EpisodeMarkIdle() => '',
    };
    final displayLabel = short && widget.cubit.pendingCount > 1
        ? '$episode · $label'
        : label;
    final previous = switch (state) {
      EpisodeMarkFailed(action: EpisodeMarkAction.undo) => l10n.playerMarked(
        episode,
      ),
      EpisodeMarkFailed(action: EpisodeMarkAction.restore) =>
        l10n.playerMarkUnset(episode),
      _ => null,
    };
    final action = switch (state) {
      EpisodeMarkOffered() => l10n.playerMarkAction,
      EpisodeMarkDone() => l10n.commonUndo,
      EpisodeMarkUndone() => l10n.playerMarkRestore,
      EpisodeMarkFailed() || EpisodeMarkQueued() => l10n.commonRetry,
      EpisodeMarkConflict() => l10n.playerMarkDismiss,
      _ => null,
    };
    void act() {
      if (state is EpisodeMarkDone ||
          state is EpisodeMarkFailed &&
              state.action == EpisodeMarkAction.undo) {
        unawaited(widget.cubit.undo());
      } else if (state is EpisodeMarkConflict) {
        widget.cubit.dismiss();
      } else {
        widget.cubit.confirm();
      }
    }

    final glyph = error
        ? PixelGlyph.markWarning
        : marked
        ? PixelGlyph.check
        : unmarked
        ? PixelGlyph.markEmpty
        : PixelGlyph.refresh;
    final color = error
        ? _warning
        : marked
        ? accent
        : _secondary;
    final animation = motionDuration(
      context,
      const Duration(milliseconds: 300),
    );
    final canExpand = action != null;
    final showAction = _open && (canExpand || loading);
    return AnimatedSize(
      duration: motionDuration(context, const Duration(milliseconds: 200)),
      alignment: Alignment.centerLeft,
      curve: Curves.easeOut,
      child: DecoratedBox(
        key: const Key('player_mark_plate'),
        decoration: BoxDecoration(
          color: _background,
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Semantics(
                button: canExpand && !loading,
                liveRegion: loading,
                label: canExpand
                    ? '$displayLabel. ${_open ? l10n.playerMarkCollapse : l10n.playerMarkExpand}'
                    : displayLabel,
                child: ExcludeSemantics(
                  child: InkWell(
                    key: const Key('player_mark_toggle'),
                    onTap: canExpand && !loading
                        ? () => setState(() {
                            _open = !_open;
                            _engaged = _open;
                            _collapseVersion++;
                          })
                        : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: short ? 6 : 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox.square(
                              dimension: 21,
                              child: DitherSwitcher(
                                duration: animation,
                                child: PixelIcon(
                                  glyph,
                                  key: ValueKey(glyph),
                                  size: 21,
                                  color: color,
                                  fineGrain: true,
                                ),
                              ),
                            ),
                            SizedBox(width: short ? 6 : 10),
                            Flexible(
                              child: DitherSwitcher(
                                duration: animation,
                                child: Column(
                                  key: ValueKey((displayLabel, previous)),
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _text,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (previous != null && !short)
                                      Text(
                                        l10n.playerMarkPreviously(previous),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _secondary,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            if (!_open && canExpand) ...[
                              const SizedBox(width: 8),
                              CustomPaint(
                                key: const Key('player_mark_disclosure'),
                                size: const Size(8, 14),
                                painter: _ChevronPainter(
                                  error ? _warning : _secondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (showAction) ...[
              const SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: _border),
              ),
              DitherSwitcher(
                duration: animation,
                child: loading
                    ? const SizedBox(
                        key: Key('player_mark_progress'),
                        width: 48,
                        height: 48,
                        child: Center(
                          child: BlockRunner(
                            color: _text,
                            trackColor: _border,
                            cell: 6,
                            gap: 2,
                          ),
                        ),
                      )
                    : TextButton(
                        key: ValueKey('player_mark_action_$action'),
                        onPressed: act,
                        style: TextButton.styleFrom(
                          foregroundColor: error
                              ? _warning
                              : marked
                              ? accent
                              : _text,
                          padding: EdgeInsets.symmetric(
                            horizontal: short ? 4 : 12,
                          ),
                          minimumSize: const Size(48, 48),
                        ),
                        child: Text(action!, maxLines: 1),
                      ),
              ),
            ],
            if (widget.cubit.pendingCount > 1) ...[
              const SizedBox(
                height: 24,
                child: VerticalDivider(width: 1, color: _border),
              ),
              Semantics(
                button: true,
                label: l10n.playerMarkNextPending(
                  widget.cubit.pendingIndex + 1,
                  widget.cubit.pendingCount,
                ),
                child: ExcludeSemantics(
                  child: TextButton(
                    key: const Key('player_mark_next_pending'),
                    onPressed: widget.cubit.showNextPending,
                    style: TextButton.styleFrom(
                      foregroundColor: _secondary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    child: Text(
                      '${widget.cubit.pendingIndex + 1}/${widget.cubit.pendingCount} ›',
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const columns = [0, 1, 2, 3, 2, 1, 0];
    final paint = Paint()..color = color;
    for (var row = 0; row < columns.length; row++) {
      canvas.drawRect(Rect.fromLTWH(columns[row] * 2, row * 2.0, 2, 2), paint);
    }
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}
