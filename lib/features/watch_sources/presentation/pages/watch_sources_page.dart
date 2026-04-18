import 'package:flutter/material.dart';

import 'package:iris/features/watch_sources/presentation/models/anime_watch_sources_args.dart';
import 'package:iris/features/watch_sources/presentation/widgets/watch_sources_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class WatchSourcesPage extends StatelessWidget {
  const WatchSourcesPage({required this.args, super.key});

  final AnimeWatchSourcesArgs args;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.watchSourcesTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              args.animeEnglishTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            const Expanded(child: WatchSourcesView()),
          ],
        ),
      ),
    );
  }
}
