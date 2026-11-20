import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/detail_layout.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({required this.child, this.action, super.key});

  final Widget child;
  final Widget? action;

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
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: action == null
          ? Align(alignment: AlignmentDirectional.centerStart, child: child)
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 360 &&
                    DetailLayout.isLargeText(context)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        child,
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: action,
                        ),
                      ],
                    ),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: child,
                      ),
                    ),
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
    required this.status,
    this.actions = const [],
    super.key,
  });

  final String title;
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
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 4,
          children: [
            Text(title, style: SettingsRow.labelStyle(theme)),
            status,
          ],
        ),
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
  });

  final String label;
  final Widget? leading;
  final Color? signalColor;
  final Color? color;
  final bool mixedData;

  @override
  Widget build(BuildContext context) {
    final leading =
        this.leading ??
        switch (signalColor) {
          final color? => SizedBox.square(
            dimension: 8,
            child: ColoredBox(color: color),
          ),
          null => null,
        };
    final style = SettingsRow.captionStyle(
      Theme.of(context),
    )?.copyWith(color: color);
    final text = mixedData
        ? MixedDataText(label, sansStyle: style)
        : Text(label, style: style);
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
