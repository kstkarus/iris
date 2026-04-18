import 'package:flutter/material.dart';

import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class AnimeListPage extends StatelessWidget {
  const AnimeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appName)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.animeListTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            const Expanded(child: AnimeListView()),
          ],
        ),
      ),
    );
  }
}
