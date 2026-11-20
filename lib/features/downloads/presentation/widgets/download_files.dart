import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/section_label.dart';
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sectionStyle = DetailLayout.queueHeadingStyle(
      theme,
    ).copyWith(fontSize: 16, fontWeight: FontWeight.w600);
    final rule = DetailLayout.ruleColor(scheme);
    final compact = WindowSizeClass.of(context).isCompact;
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 0, 16, 16)
          : const EdgeInsets.fromLTRB(24, 24, 24, 20),
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
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: DetailLayout.sansFont,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                  final info = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatByteSize(l10n, size(title)),
                        style: DetailLayout.monoTelemetryStyle(
                          theme.textTheme.bodyMedium,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PixelIcon(
                        PixelGlyph.arrowRight,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
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
                final animDuration = motionDuration(
                  context,
                  const Duration(milliseconds: 180),
                );
                final temporaryArea = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_clearMessage case final message?)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: DetailLayout.sansFont,
                            ),
                          ),
                        ),
                      ),
                    if (temporary == null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Text(
                          l10n.downloadFilesUnavailable,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: DetailLayout.sansFont,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    else if (temporary > 0) ...[
                      OverflowBar(
                        alignment: MainAxisAlignment.spaceBetween,
                        overflowAlignment: OverflowBarAlignment.start,
                        spacing: 12,
                        overflowSpacing: 4,
                        children: [
                          IntrinsicWidth(
                            child: SectionLabel(
                              l10n.downloadFilesTemporary,
                              style: sectionStyle,
                              uppercase: false,
                            ),
                          ),
                          Text(
                            formatByteSize(l10n, temporary, compact: true),
                            style: DetailLayout.monoTelemetryStyle(
                              theme.textTheme.bodyMedium,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        usage!.cacheInUse
                            ? l10n.downloadFilesTemporaryBusy
                            : l10n.downloadFilesTemporaryHint,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          key: const Key('download_files_clear_temporary'),
                          style: busyButtonStyle(
                            busy: _clearing,
                            base: ButtonStyle(
                              side: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.focused)) {
                                  return BorderSide(
                                    color: scheme.onSurface,
                                    width: 2,
                                  );
                                }
                                return BorderSide(
                                  color: states.contains(WidgetState.disabled)
                                      ? rule.withValues(alpha: 0.45)
                                      : rule,
                                );
                              }),
                            ),
                          ),
                          onPressed: usage.cacheInUse || _clearing
                              ? null
                              : _clear,
                          child: BusyButtonChild(
                            l10n.downloadStorageClearCache,
                            busy: _clearing,
                            semanticsLabel: l10n.downloadFilesClearTemporary,
                            busySemanticsLabel:
                                l10n.downloadFilesClearingTemporary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Divider(height: 1, thickness: 1, color: rule),
                      const SizedBox(height: 20),
                    ],
                  ],
                );
                return ListView(
                  shrinkWrap: true,
                  children: [
                    if (animDuration == Duration.zero)
                      temporaryArea
                    else
                      AnimatedSize(
                        duration: animDuration,
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: temporaryArea,
                      ),
                    SectionLabel(
                      l10n.downloadFilesSaved,
                      style: sectionStyle,
                      uppercase: false,
                    ),
                    const SizedBox(height: 8),
                    if (titles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          l10n.downloadFilesEmpty,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: DetailLayout.sansFont,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (final title in titles)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: rule.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                        child: TapRow(
                          inkKey: ValueKey('download_files_title_${title.key}'),
                          onTap: () => Navigator.pop(context, title),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: fileRow(title),
                          ),
                        ),
                      ),
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
