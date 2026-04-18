import 'package:flutter/material.dart';

import 'package:iris/features/player/presentation/widgets/player_view.dart';
import 'package:iris/features/player/presentation/widgets/player_viewport_factory.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({required this.viewportFactory, super.key});

  final PlayerViewportFactory viewportFactory;

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
            Text(l10n.playerTitle, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 20),
            Expanded(child: PlayerView(viewportFactory: viewportFactory)),
          ],
        ),
      ),
    );
  }
}
