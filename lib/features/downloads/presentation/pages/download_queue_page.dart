import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_files.dart';
import 'package:iris/features/downloads/presentation/widgets/download_queue.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/status_views.dart';

class DownloadQueuePage extends StatelessWidget {
  const DownloadQueuePage({required this.onOpenTitle, super.key});
  final ValueChanged<DownloadTitle> onOpenTitle;

  Future<void> _files(BuildContext context) async {
    final title = await showDownloadFiles(context);
    if (title != null && context.mounted) onOpenTitle(title);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ScaffoldMessenger(
      child: Scaffold(
        key: const Key('download_queue_page'),
        appBar: FramedAppBar(title: PageTitle(title: l10n.downloadQueueTitle)),
        body: SafeArea(
          top: false,
          child: PageFrame.subPage(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
                  builder: (context, state) {
                    final Widget view;
                    if (state.downloads.isEmpty && state.isLoading) {
                      view = LoadingView(
                        key: const ValueKey('download_queue_loading'),
                        semanticsLabel: l10n.downloadsLoading,
                      );
                    } else if (state.downloads.isEmpty && state.hasError) {
                      view = RetryView(
                        key: const ValueKey('download_queue_error'),
                        message: l10n.downloadManagerUnableToLoad,
                        onRetry: context.read<DownloadManagerCubit>().load,
                      );
                    } else {
                      view = KeyedSubtree(
                        key: const ValueKey('download_queue_ready'),
                        child: DownloadQueueView(
                          onFiles: () => _files(context),
                        ),
                      );
                    }
                    return DitherSwitcher(
                      expand: true,
                      duration: const Duration(milliseconds: 220),
                      child: view,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
