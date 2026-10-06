import 'package:flutter/material.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

class DownloadManagerPage extends StatelessWidget {
  const DownloadManagerPage({required this.onWatch, super.key});

  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.downloadsTitle)),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(margin, 16, margin, 0),
          child: MaxWidthBox(
            maxWidth: AdaptiveContentWidth.page,
            child: DownloadManagerView(onWatch: onWatch),
          ),
        ),
      ),
    );
  }
}
