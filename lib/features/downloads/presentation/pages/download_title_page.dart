import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

class DownloadTitlePage extends StatelessWidget {
  const DownloadTitlePage({
    required this.title,
    required this.onWatch,
    this.onOpenAnime,
    super.key,
  });
  final DownloadTitle title;
  final ValueChanged<DownloadItem> onWatch;
  final ValueChanged<DownloadTitle>? onOpenAnime;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: PageFrame(
        child: DownloadManagerView(
          titleKey: title.key,
          onWatch: onWatch,
          onOpenTitle: (_) {},
          onOpenAnime: onOpenAnime,
          onBrowseCatalog: () {},
          onTitleDeleted: () {
            if (context.mounted) Navigator.of(context).maybePop();
          },
        ),
      ),
    ),
  );
}
