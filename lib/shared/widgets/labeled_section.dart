import 'package:flutter/material.dart';

import 'package:iris/shared/widgets/section_label.dart';

/// A section as a spec row: its [label] in a column of its own on the
/// left and the [child] beside it, or the label above the child when no
/// [labelWidth] is given (narrow windows).
class LabeledSection extends StatelessWidget {
  const LabeledSection({
    required this.label,
    required this.child,
    this.labelWidth,
    this.labelStyle,
    this.uppercase = true,
    this.showPrefix = true,
    super.key,
  });

  final String label;
  final Widget child;
  final double? labelWidth;
  final TextStyle? labelStyle;
  final bool uppercase;
  final bool showPrefix;

  @override
  Widget build(BuildContext context) {
    final labelWidth = this.labelWidth;
    final heading = SectionLabel(
      label,
      style: labelStyle,
      uppercase: uppercase,
      showPrefix: showPrefix,
    );
    if (labelWidth == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [heading, const SizedBox(height: 12), child],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 3, right: 24),
            child: heading,
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
