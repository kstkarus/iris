import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_state.dart';
import 'package:iris/features/downloads/presentation/widgets/download_files.dart';
import 'package:iris/features/downloads/presentation/widgets/download_queue.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/status_views.dart';

class DownloadQueuePage extends StatelessWidget {
  const DownloadQueuePage({required this.onOpenTitle, super.key});
  final ValueChanged<DownloadTitle> onOpenTitle;

  Future<void> _files(BuildContext context) async {
    final title = await showDownloadFiles(context);
    if (title != null && context.mounted) onOpenTitle(title);
  }

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Scaffold(
      key: const Key('download_queue_page'),
      body: SafeArea(
        child: PageFrame(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 800,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const BackButton(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text(
                            AppLocalizations.of(context).downloadQueueTitle,
                            maxLines: 2,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child:
                        BlocBuilder<DownloadManagerCubit, DownloadManagerState>(
                          builder: (context, state) {
                            if (state.downloads.isEmpty && state.isLoading) {
                              return LoadingView(
                                semanticsLabel: AppLocalizations.of(
                                  context,
                                ).downloadsLoading,
                              );
                            }
                            if (state.downloads.isEmpty && state.hasError) {
                              return RetryView(
                                message: AppLocalizations.of(
                                  context,
                                ).downloadManagerUnableToLoad,
                                onRetry: context
                                    .read<DownloadManagerCubit>()
                                    .load,
                              );
                            }
                            return DownloadQueueView(
                              onFiles: () => _files(context),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
