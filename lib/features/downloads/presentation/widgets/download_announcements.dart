import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'package:iris/features/downloads/domain/entities/download_item.dart';
import 'package:iris/features/downloads/domain/entities/download_status.dart';
import 'package:iris/features/downloads/domain/repositories/downloads_repository.dart';
import 'package:iris/features/downloads/presentation/widgets/download_labels.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

class DownloadAnnouncements extends StatefulWidget {
  const DownloadAnnouncements({
    required this.repository,
    required this.child,
    super.key,
  });

  final DownloadsRepository repository;
  final Widget child;

  @override
  State<DownloadAnnouncements> createState() => _DownloadAnnouncementsState();
}

class _DownloadAnnouncementsState extends State<DownloadAnnouncements> {
  StreamSubscription<List<DownloadItem>>? _subscription;
  Map<String, DownloadStatus> _statuses = {};
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _subscription ??= _listen();
  }

  @override
  void didUpdateWidget(DownloadAnnouncements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository)) {
      unawaited(_subscription?.cancel());
      _statuses = {};
      _subscription = _listen();
    }
  }

  StreamSubscription<List<DownloadItem>> _listen() {
    final generation = ++_generation;
    return widget.repository.watchDownloads().listen(
      (items) {
        if (!mounted || generation != _generation) return;
        final previous = _statuses;
        _statuses = {for (final item in items) item.id: item.status};
        final l10n = AppLocalizations.of(context);
        for (final item in items) {
          final before = previous[item.id];
          if (before == null || before == item.status) continue;
          final message = switch (item.status) {
            DownloadStatus.completed => l10n.downloadAnnounceCompleted(
              downloadName(l10n, item),
            ),
            DownloadStatus.failed => l10n.downloadAnnounceFailed(
              downloadName(l10n, item),
            ),
            _ => null,
          };
          if (message != null) {
            SemanticsService.sendAnnouncement(
              View.of(context),
              message,
              Directionality.of(context),
            );
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Unable to watch download announcements.',
          name: 'iris.downloads.announcements',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
