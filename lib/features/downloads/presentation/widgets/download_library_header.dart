import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';

class DownloadLibraryHeader extends StatelessWidget {
  const DownloadLibraryHeader({
    required this.queueCount,
    required this.showQueue,
    required this.onFiles,
    this.onQueue,
    super.key,
  });

  final int queueCount;
  final bool showQueue;
  final VoidCallback? onQueue;
  final VoidCallback onFiles;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact =
            constraints.maxWidth < 328 ||
            MediaQuery.textScalerOf(context).scale(16) > 22;
        final queueLabel = queueCount > 0
            ? l10n.downloadQueueCount(queueCount)
            : l10n.downloadQueueButton;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.navigationDownloads,
                    key: const Key('download_library_heading'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              if (showQueue)
                TextButton(
                  key: const Key('download_queue_open'),
                  onPressed: onQueue,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  child: compact
                      ? Tooltip(
                          message: queueLabel,
                          child: Semantics(
                            label: queueLabel,
                            excludeSemantics: true,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const PixelIcon(PixelGlyph.download, size: 14),
                                if (queueCount > 0) ...[
                                  const SizedBox(width: 8),
                                  Text('$queueCount'),
                                ],
                              ],
                            ),
                          ),
                        )
                      : Text(queueLabel),
                ),
              if (compact)
                IconButton(
                  key: const Key('download_files_open'),
                  tooltip: l10n.downloadFilesTitle,
                  onPressed: onFiles,
                  icon: const PixelIcon(PixelGlyph.file, size: 18),
                )
              else
                Padding(
                  padding: EdgeInsets.only(left: showQueue ? 12 : 0),
                  child: TextButton(
                    key: const Key('download_files_open'),
                    onPressed: onFiles,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(l10n.downloadFilesButton),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
