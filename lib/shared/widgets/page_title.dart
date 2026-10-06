import 'package:flutter/material.dart';

/// App bar title with an optional one-line subtitle (Material small top app
/// bar): what the page is, then what it is about.
class PageTitle extends StatelessWidget {
  const PageTitle({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final subtitle = this.subtitle;
    final titleText = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (subtitle == null || subtitle.isEmpty) return titleText;

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        titleText,
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
