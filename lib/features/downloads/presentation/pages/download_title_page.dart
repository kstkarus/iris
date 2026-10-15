import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

class DownloadTitlePage extends StatelessWidget {
  const DownloadTitlePage({
    required this.title,
    required this.onWatch,
    super.key,
  });
  final DownloadTitle title;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const BackButton(),
                Text(
                  AppLocalizations.of(
                    context,
                  ).downloadTitlesTitle.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DownloadManagerView(
                titleKey: title.key,
                onWatch: onWatch,
                onOpenTitle: (_) {},
                onBrowseCatalog: () {},
                onTitleDeleted: () {
                  if (context.mounted) Navigator.of(context).maybePop();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
