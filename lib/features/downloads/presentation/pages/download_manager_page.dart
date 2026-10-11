import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({
    required this.onWatch,
    required this.onBrowseCatalog,
    super.key,
  });

  final ValueChanged<DownloadItem> onWatch;
  final VoidCallback onBrowseCatalog;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: DownloadManagerView(
            onWatch: onWatch,
            onBrowseCatalog: onBrowseCatalog,
          ),
        ),
      ),
    );
  }
}
