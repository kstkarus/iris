import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_state.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';
import 'package:iris/features/downloads/presentation/widgets/download_selection_view.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';

class DownloadSelectionPage extends StatelessWidget {
  const DownloadSelectionPage({
    required this.args,
    required this.onQueued,
    super.key,
  });

  final DownloadSelectionArgs args;
  final ValueChanged<DownloadItem> onQueued;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<DownloadSelectionCubit, DownloadSelectionState>(
      listenWhen: (_, state) => state is DownloadSelectionQueued,
      listener: (context, state) {
        onQueued((state as DownloadSelectionQueued).item);
      },
      child: Scaffold(
        appBar: FramedAppBar(
          title: PageTitle(
            title: l10n.downloadSelectionTitle,
            subtitle: args.sourceTitle,
          ),
        ),
        body: SafeArea(
          child: PageFrame.subPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [const Expanded(child: DownloadSelectionView())],
            ),
          ),
        ),
      ),
    );
  }
}
