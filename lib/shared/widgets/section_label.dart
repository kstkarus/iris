import 'package:flutter/material.dart';

/// A section heading, small and upper case by default, with an optional
/// [trailing] action at the end of the row.
///
/// It carries no rule of its own: the rows below it bring theirs.
class SectionLabel extends StatelessWidget {
  const SectionLabel(
    this.text, {
    this.trailing,
    this.style,
    this.uppercase = true,
    super.key,
  });

  final String text;
  final Widget? trailing;
  final TextStyle? style;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = this.style ?? theme.textTheme.labelSmall;
    final trailing = this.trailing;
    final labelText = uppercase ? text.toUpperCase() : text;
    return Semantics(
      header: true,
      child: Row(
        children: [
          Expanded(child: Text(labelText, style: style)),
          ?trailing,
        ],
      ),
    );
  }
}
