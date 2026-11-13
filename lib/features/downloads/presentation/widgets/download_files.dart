import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

Future<DownloadTitle?> showDownloadFiles(BuildContext context) {
  final cubit = context.read<DownloadManagerCubit>();
  unawaited(cubit.refreshStorage());
  return showAdaptiveSheet<DownloadTitle>(
    context: context,
    builder: (_) =>
        BlocProvider.value(value: cubit, child: const _DownloadFiles()),
  );
}

class _DownloadFiles extends StatefulWidget {
  const _DownloadFiles();

  @override
  State<_DownloadFiles> createState() => _DownloadFilesState();
}

class _DownloadFilesState extends State<_DownloadFiles> {
  bool _clearing = false;
  String? _clearMessage;

  Future<void> _clear() async {
    final cubit = context.read<DownloadManagerCubit>();
    final l10n = AppLocalizations.of(context);
    setState(() {
      _clearing = true;
      _clearMessage = null;
    });
    final cleared = await cubit.clearCache();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _clearMessage = cleared
          ? l10n.downloadFilesTemporaryCleared
          : cubit.state.storageUsage?.cacheInUse == true
          ? l10n.downloadFilesTemporaryBusy
          : l10n.downloadFilesClearFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        key: const Key('download_files_sheet'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.downloadFilesTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const PixelIcon(PixelGlyph.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
              builder: (context, state) {
                int size(DownloadTitle title) => title.items.fold(
                  0,
                  (total, item) => total + item.downloadedBytes,
                );
                final titles = downloadTitles(state.downloads)
                  ..sort((a, b) => size(b).compareTo(size(a)));
                Widget fileRow(DownloadTitle title) {
                  final identity = Text(
                    title.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  );
                  final info = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatByteSize(l10n, size(title)),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(width: 12),
                      const PixelIcon(PixelGlyph.arrowRight, size: 14),
                    ],
                  );
                  if (MediaQuery.textScalerOf(context).scale(16) > 23) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        identity,
                        const SizedBox(height: 4),
                        Align(alignment: Alignment.centerRight, child: info),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: identity),
                      const SizedBox(width: 16),
                      info,
                    ],
                  );
                }

                final usage = state.storageUsage;
                final temporary = usage?.cacheBytes;
                return ListView(
                  shrinkWrap: true,
                  children: [
                    if (_clearMessage case final message?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    if (temporary == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                          l10n.downloadFilesUnavailable,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    if (temporary != null && temporary > 0) ...[
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        overflowAlignment: OverflowBarAlignment.start,
                        spacing: 12,
                        overflowSpacing: 4,
                        children: [
                          IntrinsicWidth(
                            child: SectionLabel(l10n.downloadFilesTemporary),
                          ),
                          Text(
                            formatByteSize(l10n, temporary, compact: true),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        usage!.cacheInUse
                            ? l10n.downloadFilesTemporaryBusy
                            : l10n.downloadFilesTemporaryHint,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          key: const Key('download_files_clear_temporary'),
                          onPressed: usage.cacheInUse || _clearing
                              ? null
                              : _clear,
                          child: _clearing
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel:
                                        l10n.downloadFilesClearTemporary,
                                  ),
                                )
                              : Text(
                                  l10n.downloadStorageClearCache,
                                  semanticsLabel:
                                      l10n.downloadFilesClearTemporary,
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    SectionLabel(l10n.downloadFilesSaved),
                    const SizedBox(height: 8),
                    if (titles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l10n.downloadFilesEmpty,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    for (final title in titles) ...[
                      const SegmentedRule(),
                      TapRow(
                        inkKey: ValueKey('download_files_title_${title.key}'),
                        onTap: () => Navigator.pop(context, title),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: fileRow(title),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
