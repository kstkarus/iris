import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/signal_badge.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    required this.onPressed,
    this.inTopBar = false,
    super.key,
  });

  static const updateSignalKey = Key('settings_update_signal');

  final VoidCallback onPressed;
  final bool inTopBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final hasDismissedUpdate = context.select<AppUpdateCubit?, bool>(
      (cubit) => cubit?.state.hasDismissedUpdate ?? false,
    );
    final baseTooltip = inTopBar
        ? l10n.settingsShortcutTooltip
        : l10n.settingsTitle;
    final tooltip = hasDismissedUpdate
        ? '$baseTooltip · ${l10n.settingsUpdateAvailableHint}'
        : baseTooltip;
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      alignment: inTopBar ? Alignment.center : AlignmentDirectional.centerEnd,
      icon: SignalBadge(
        visible: hasDismissedUpdate,
        size: 6,
        top: -2,
        end: -2,
        cutout: true,
        dotKey: updateSignalKey,
        child: const PixelIcon(PixelGlyph.settings, size: 18),
      ),
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused) ||
                  states.contains(WidgetState.pressed)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
        overlayColor: inTopBar
            ? null
            : const WidgetStatePropertyAll(Colors.transparent),
      ),
    );
  }
}
