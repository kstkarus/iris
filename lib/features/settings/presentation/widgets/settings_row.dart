import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({required this.child, this.action, super.key});

  final Widget child;
  final Widget? action;

  static const contentPadding = EdgeInsets.symmetric(vertical: 12);

  static TextStyle? labelStyle(ThemeData theme) =>
      theme.textTheme.bodyMedium?.copyWith(
        fontFamily: DetailLayout.sansFont,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      );

  static TextStyle? captionStyle(ThemeData theme) =>
      theme.textTheme.bodySmall?.copyWith(
        fontFamily: DetailLayout.sansFont,
        fontSize: 13,
        color: theme.colorScheme.onSurfaceVariant,
      );

  @override
  Widget build(BuildContext context) {
    final action = this.action;
    final content = Padding(padding: contentPadding, child: child);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360 && DetailLayout.isLargeText(context)) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                content,
                if (action != null)
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    end: action == null ? 0 : 12,
                  ),
                  child: content,
                ),
              ),
              if (action != null)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth / 2,
                  ),
                  child: action,
                ),
            ],
          );
        },
      ),
    );
  }
}

ButtonStyle settingsActionStyle(BuildContext context, {bool primary = false}) {
  final scheme = Theme.of(context).colorScheme;
  return ButtonStyle(
    alignment: AlignmentDirectional.centerEnd,
    padding: const WidgetStatePropertyAll(
      EdgeInsetsDirectional.only(start: 12),
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          !states.contains(WidgetState.disabled) &&
              (primary ||
                  states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused))
          ? scheme.onSurface
          : scheme.onSurfaceVariant,
    ),
  );
}

class SettingsAccountRow extends StatelessWidget {
  const SettingsAccountRow({
    required this.title,
    required this.statusKey,
    required this.status,
    this.actions = const [],
    super.key,
  });

  final String title;
  final Object statusKey;
  final Widget status;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsRow(
      action: actions.isEmpty
          ? null
          : Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(title, style: SettingsRow.labelStyle(theme)),
          DitherSwitcher(
            duration: const Duration(milliseconds: 220),
            resizeDuration: const Duration(milliseconds: 200),
            child: Semantics(
              key: ValueKey(statusKey),
              liveRegion: true,
              child: status,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsStatus extends StatelessWidget {
  const SettingsStatus(
    this.label, {
    this.leading,
    this.signalColor,
    this.color,
    this.mixedData = false,
    super.key,
  }) : _loading = false;

  const SettingsStatus.loading(this.label, {super.key})
    : leading = null,
      signalColor = null,
      color = null,
      mixedData = false,
      _loading = true;

  final String label;
  final Widget? leading;
  final Color? signalColor;
  final Color? color;
  final bool mixedData;
  final bool _loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = SettingsRow.captionStyle(theme);
    if (_loading) {
      return PixelNoise.shimmer(
        child: Text(
          label,
          style: style?.copyWith(color: theme.colorScheme.onSurface),
        ),
      );
    }
    final leading =
        this.leading ??
        switch (signalColor) {
          final color? => SizedBox.square(
            dimension: 8,
            child: ColoredBox(color: color),
          ),
          null => null,
        };
    final statusStyle = style?.copyWith(color: color);
    final text = mixedData
        ? MixedDataText(label, sansStyle: statusStyle)
        : Text(label, style: statusStyle);
    return leading == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 8),
              Flexible(child: text),
            ],
          );
  }
}
