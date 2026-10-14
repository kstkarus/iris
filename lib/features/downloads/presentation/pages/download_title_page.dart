import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_title.dart';
import 'package:iris/features/downloads/presentation/widgets/download_manager_view.dart';
import 'package:iris/shared/widgets/adaptive/framed_app_bar.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/page_title.dart';

class DownloadTitlePage extends StatelessWidget {
  const DownloadTitlePage({
    required this.title,
    required this.onWatch,
    super.key,
  });

  final DownloadTitle title;
  final ValueChanged<DownloadItem> onWatch;

  @override
  Widget build(BuildContext context) {
    final count = context.select<DownloadManagerCubit, int>(
      (cubit) => cubit.state.downloads
          .where((item) => downloadTitleKey(item) == title.key)
          .length,
    );
    return Scaffold(
      appBar: FramedAppBar(
        title: PageTitle(title: title.name),
        trailing: count > 1
            ? IconButton(
                tooltip: AppLocalizations.of(context).downloadDeleteAll,
                icon: const PixelIcon(PixelGlyph.delete, size: 18),
                onPressed: () async {
                  final items = context
                      .read<DownloadManagerCubit>()
                      .state
                      .downloads
                      .where((item) => downloadTitleKey(item) == title.key)
                      .toList();
                  final removed = await confirmDownloadDeletion(
                    context,
                    items,
                    title.name,
                    all: true,
                  );
                  if (removed && context.mounted) {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : null,
      ),
      body: SafeArea(
        child: PageFrame.subPage(
          child: DownloadManagerView(
            titleKey: title.key,
            onWatch: onWatch,
            onOpenTitle: (_) {},
            onBrowseCatalog: () {},
          ),
        ),
      ),
    );
  }
}
