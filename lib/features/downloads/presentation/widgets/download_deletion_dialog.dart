import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/adaptive/show_app_dialog.dart';

/// The same confirmation for one file or all downloads of a title.
Future<bool> confirmDownloadDeletion(
  BuildContext context,
  List<DownloadItem> items,
  String name, {
  bool all = false,
}) async {
  if (items.isEmpty) return false;
  final l10n = AppLocalizations.of(context);
  final lost = items
      .where((item) => item.status != DownloadStatus.completed)
      .fold<int>(0, (sum, item) => sum + item.downloadedBytes);
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(all ? l10n.downloadDeleteAll : l10n.downloadDeleteTitle),
      content: Text(
        [
          all
              ? l10n.downloadDeleteTitleMessage(name)
              : l10n.downloadDeleteMessage(name),
          if (lost > 0)
            l10n.downloadDeleteProgressLost(formatByteSize(l10n, lost)),
        ].join(' '),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.downloadCancelButton),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(l10n.downloadDeleteButton),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;
  final cubit = context.read<DownloadManagerCubit>();
  final messenger = ScaffoldMessenger.of(context);
  var deleted = true;
  for (final item in items) {
    if (!await cubit.delete(item.id)) deleted = false;
  }
  if (!deleted && context.mounted) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.downloadDeleteFailed)));
  }
  return deleted;
}
