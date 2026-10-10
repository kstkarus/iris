import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

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
    final sizeClass = WindowSizeClass.of(context);
    final margin = sizeClass.pageMargin;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, sizeClass.pageTop, margin, 0),
          child: MaxWidthBox(
            maxWidth: AdaptiveContentWidth.page,
            child: DownloadManagerView(
              onWatch: onWatch,
              onBrowseCatalog: onBrowseCatalog,
            ),
          ),
        ),
      ),
    );
  }
}
