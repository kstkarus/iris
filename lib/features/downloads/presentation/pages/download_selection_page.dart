import 'package:flutter/material.dart';

import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';

/// Picks the files of a torrent or the episodes of an online release to
/// download. It stays open: every file tapped is queued and shows how its
/// download goes, so a season is a tap per episode.
class DownloadSelectionPage extends StatelessWidget {
  const DownloadSelectionPage({required this.args, super.key});

  final DownloadSelectionArgs args;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: FramedAppBar(
        title: PageTitle(
          title: args.isOnlineRelease
              ? l10n.downloadSelectionEpisodeTitle
              : l10n.downloadSelectionTitle,
          subtitle: args.sourceTitle,
        ),
      ),
      body: SafeArea(
        child: PageFrame.subPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [const Expanded(child: DownloadSelectionView())],
          ),
        ),
      ),
    );
  }
}
