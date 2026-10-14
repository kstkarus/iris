import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({
    required this.onWatch,
    required this.onBrowseCatalog,
    required this.onOpenTitle,
    this.titleKey,
    super.key,
  });

  final ValueChanged<DownloadItem> onWatch;
  final VoidCallback onBrowseCatalog;
  final ValueChanged<DownloadTitle> onOpenTitle;
  final String? titleKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: DownloadManagerView(
            onWatch: onWatch,
            onBrowseCatalog: onBrowseCatalog,
            onOpenTitle: onOpenTitle,
            titleKey: titleKey,
          ),
        ),
      ),
    );
  }
}
