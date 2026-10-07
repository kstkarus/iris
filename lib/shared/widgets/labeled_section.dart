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
    super.key,
  });

  final String label;
  final Widget child;
  final double? labelWidth;

  @override
  Widget build(BuildContext context) {
    final labelWidth = this.labelWidth;
    if (labelWidth == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionLabel(label), const SizedBox(height: 12), child],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: 3, right: 24),
            child: SectionLabel(label),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
