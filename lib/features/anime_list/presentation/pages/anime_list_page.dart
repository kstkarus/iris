import 'package:flutter/material.dart';

import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

class AnimeListPage extends StatelessWidget {
  const AnimeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navigationCatalog)),
      body: Padding(
        padding: EdgeInsets.fromLTRB(margin, 16, margin, 0),
        child: const MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: AnimeListView(),
        ),
      ),
    );
  }
}
