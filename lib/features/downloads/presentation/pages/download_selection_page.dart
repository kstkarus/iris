import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_view.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';

/// Downloads individual files or a selected batch without leaving the source.
class DownloadSelectionPage extends StatelessWidget {
  const DownloadSelectionPage({
    required this.args,
    required this.onWatch,
    super.key,
  });

  final DownloadSelectionArgs args;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: BlocBuilder<DownloadSelectionCubit, DownloadSelectionState>(
          builder: (context, state) => DitherSwitcher(
            duration: const Duration(milliseconds: 200),
            expand: true,
            child: switch (state) {
              final DownloadSelectionReady ready when ready.selecting =>
                FramedAppBar(
                  key: const ValueKey('download_selection_actions'),
                  showBackButton: false,
                  title: _SelectionActions(state: ready),
                ),
              _ => FramedAppBar(
                key: const ValueKey('download_selection_title'),
                title: PageTitle(
                  title: args.isOnlineRelease
                      ? l10n.downloadSelectionEpisodeTitle
                      : l10n.downloadSelectionTitle,
                  subtitle: args.sourceTitle,
                ),
              ),
            },
          ),
        ),
      ),
      body: SafeArea(
        child: PageFrame.subPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: DownloadSelectionView(onWatch: onWatch)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionActions extends StatelessWidget {
  const _SelectionActions({required this.state});

  final DownloadSelectionReady state;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DownloadSelectionCubit>();
    final l10n = AppLocalizations.of(context);
    final allSelected = state.source.files
        .where((file) => state.canSelect(file.index))
        .every((file) => state.selected.contains(file.index));
    final style = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: TextButton(
            key: const Key('download_selection_cancel'),
            style: style,
            onPressed: state.addingBatch ? null : cubit.cancelSelection,
            child: Text(l10n.downloadCancelButton, maxLines: 2),
          ),
        ),
        Flexible(
          child: TextButton(
            key: const Key('download_selection_all'),
            style: style,
            onPressed: state.addingBatch ? null : cubit.selectAll,
            child: Text(
              allSelected ? l10n.downloadDeselectAll : l10n.downloadSelectAll,
              maxLines: 2,
              textAlign: TextAlign.end,
            ),
          ),
        ),
      ],
    );
  }
}
