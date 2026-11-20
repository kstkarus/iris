import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class SettingsIconButton extends StatelessWidget {
  const SettingsIconButton({
    required this.onPressed,
    this.inTopBar = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool inTopBar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return IconButton(
      onPressed: onPressed,
      tooltip: inTopBar ? l10n.settingsShortcutTooltip : l10n.settingsTitle,
      padding: inTopBar
          ? const EdgeInsetsDirectional.only(start: 20)
          : EdgeInsets.zero,
      alignment: inTopBar ? null : AlignmentDirectional.centerEnd,
      icon: const PixelIcon(PixelGlyph.settings, size: 18),
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
