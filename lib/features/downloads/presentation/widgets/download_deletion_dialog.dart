import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/presentation/cubit/download_manager_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/adaptive/show_app_dialog.dart';

/// Null means cancelled; otherwise returns the copies that remain to delete.
Future<Set<String>?> confirmDownloadDeletion(
  BuildContext context,
  List<DownloadItem> items,
  String name, {
  bool all = false,
  bool selected = false,
}) async {
  if (items.isEmpty) return null;
  final cubit = context.read<DownloadManagerCubit>();
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  final batch = all || selected;
  final unfinished = items
      .where((item) => item.status != DownloadStatus.completed)
      .length;
  final bytes = items.fold<int>(0, (sum, item) => sum + item.downloadedBytes);
  final lost = items
      .where((item) => item.status != DownloadStatus.completed)
      .fold<int>(0, (sum, item) => sum + item.downloadedBytes);
  Future<bool?>? dismissed;
  final confirmed = await showAppDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const Key('download_delete_confirmation'),
      scrollable: true,
      title: Text(
        batch
            ? l10n.downloadDeleteSelectedTitle(items.length)
            : l10n.downloadDeleteTitle,
      ),
      content: Text(
        [
          batch ? name : l10n.downloadDeleteMessage(name),
          if (batch && bytes > 0)
            l10n.downloadDeleteSpace(formatByteSize(l10n, bytes)),
          if (batch && unfinished > 0) l10n.downloadDeleteUnfinished,
          if (!batch && lost > 0)
            l10n.downloadDeleteProgressLost(formatByteSize(l10n, lost)),
        ].join(' '),
      ),
      actions: [
        TextButton(
          key: const Key('download_delete_dismiss'),
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(l10n.downloadCancelButton),
        ),
        FilledButton(
          key: const Key('download_delete_confirm'),
          onPressed: () {
            dismissed = ModalRoute.of<bool>(dialogContext)?.completed;
            Navigator.pop(dialogContext, true);
          },
          child: Text(l10n.downloadDeleteButton),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;
  // The rows should start leaving once the confirmation is out of the way.
  await dismissed;
  if (cubit.isClosed) return null;
  final failed = await cubit.deleteMany(items.map((item) => item.id));
  if (failed.isNotEmpty && !selected && messenger.mounted) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          batch
              ? l10n.downloadDeleteSelectionFailed(failed.length)
              : l10n.downloadDeleteFailed,
        ),
      ),
    );
  }
  return failed;
}
