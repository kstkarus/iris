import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/domain/entities/app_version.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/busy_button_child.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';
import 'package:iris/shared/widgets/pixel_separated_text.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/status_views.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Opens [url] outside the app; false when nothing could.
typedef OpenExternalUrl = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// Opens the release notes and update actions sheet/dialog when a release
/// is available in [AppUpdateCubit].
Future<void> showAppUpdateSheet(
  BuildContext context, {
  OpenExternalUrl? open,
}) async {
  final cubit = context.read<AppUpdateCubit>();
  final release = cubit.state.availableRelease;
  if (release == null) return;
  final windows = Theme.of(context).platform == TargetPlatform.windows;
  await showAdaptiveSheet<void>(
    context: context,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: _UpdateSheet(
        release: release,
        windows: windows,
        open: open ?? _openInBrowser,
      ),
    ),
  );
}

String appUpdatePhaseLabel(
  AppLocalizations l10n,
  AppUpdateState state, {
  required bool windows,
  bool includeDownloadVersion = false,
}) => switch (state.phase) {
  AppUpdatePhase.available => l10n.appUpdateNoticeAvailable(
    '${state.availableRelease!.version}',
  ),
  AppUpdatePhase.downloading when includeDownloadVersion =>
    l10n.appUpdateNoticeDownloadingVersion(
      '${state.availableRelease!.version}',
    ),
  AppUpdatePhase.downloading => l10n.appUpdateNoticeDownloading,
  AppUpdatePhase.verifying => l10n.appUpdateNoticeVerifying,
  AppUpdatePhase.ready => switch (state.failure) {
    AppUpdateFailureKind.permission => l10n.appUpdateNoticePermissionNeeded,
    AppUpdateFailureKind.install => l10n.appUpdateNoticeInstallFailed,
    _ => windows ? l10n.appUpdateNoticeRestartReady : l10n.appUpdateNoticeReady,
  },
  AppUpdatePhase.installing =>
    windows ? l10n.appUpdateNoticeRestarting : l10n.appUpdateNoticeInstalling,
  AppUpdatePhase.failed =>
    state.failure == AppUpdateFailureKind.invalidFile
        ? l10n.appUpdateFailureInvalidFile
        : l10n.appUpdateNoticeFailed,
};

/// An update strip above [child]. Tapping it opens the adaptive update modal
/// with release notes and actions: in-app download/install on Android and
/// installed Windows, or an external build download on iOS and portable Windows.
///
/// The strip takes the status bar inset from [child] while it is visible, so
/// the page below keeps its position as the strip opens and closes.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    required this.child,
    this.open = _openInBrowser,
    super.key,
  });

  static const noticeKey = Key('update_notice');
  static const noticeLabelSwitcherKey = Key('update_notice_label_switcher');
  static const sheetKey = Key('update_sheet');
  static const headerKey = Key('update_sheet_header');
  static const notesScrollKey = Key('update_sheet_notes_scroll');
  static const footerKey = Key('update_sheet_footer');
  static const laterKey = Key('update_notice_later');
  static const downloadActionKey = Key('update_download_action');
  static const cancelDownloadKey = Key('update_cancel_download');
  static const installKey = Key('update_install');

  final Widget child;
  final OpenExternalUrl open;

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<AppUpdateCubit?>();
    return _DevelopingNotice(
      state: cubit?.state ?? const AppUpdateState(),
      inAppUpdate: cubit?.supportsInAppUpdate ?? false,
      open: open,
      child: child,
    );
  }
}

/// Preserves the existing two-stage Bayer reveal and inset handoff.
class _DevelopingNotice extends StatefulWidget {
  const _DevelopingNotice({
    required this.state,
    required this.inAppUpdate,
    required this.open,
    required this.child,
  });

  final AppUpdateState state;
  final bool inAppUpdate;
  final OpenExternalUrl open;
  final Widget child;

  @override
  State<_DevelopingNotice> createState() => _DevelopingNoticeState();
}

class _DevelopingNoticeState extends State<_DevelopingNotice>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _controller = AnimationController(
    vsync: this,
    duration: DitherTransition.duration * 2,
    value: widget.state.release == null ? 0 : 1,
  );

  late AppUpdateState _shown = widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.inAppUpdate) {
      context.read<AppUpdateCubit?>()?.resumeInstallation();
    }
  }

  @override
  void didUpdateWidget(_DevelopingNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    final release = widget.state.release;
    if (release != null) _shown = widget.state;
    if ((release == null) == (oldWidget.state.release == null)) return;
    final target = release == null ? 0.0 : 1.0;
    final duration = motionDuration(
      context,
      release == null
          ? const Duration(milliseconds: 240)
          : DitherTransition.duration * 2,
    );
    if (duration == Duration.zero) {
      _controller.value = target;
    } else {
      _controller.animateTo(
        target,
        duration: duration,
        curve: release == null ? Curves.easeOutCubic : Curves.linear,
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final opened = Curves.easeInOut.transform(
          (_controller.value * 2).clamp(0.0, 1.0),
        );
        final developed = (_controller.value * 2 - 1).clamp(0.0, 1.0);
        final shown = _shown;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (opened > 0 && shown.release != null)
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: opened,
                  child: IgnorePointer(
                    ignoring: developed < 1,
                    child: BayerMasked(
                      open: (developed * BayerMask.steps).round(),
                      child: _Strip(
                        state: shown,
                        open: widget.open,
                        topInset: media.padding.top,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            Expanded(
              child: MediaQuery(
                data: media.copyWith(
                  padding: media.padding.copyWith(
                    top: media.padding.top * (1 - opened),
                  ),
                  viewPadding: media.viewPadding.copyWith(
                    top: media.viewPadding.top * (1 - opened),
                  ),
                ),
                child: child!,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({
    required this.state,
    required this.open,
    required this.topInset,
  });

  final AppUpdateState state;
  final OpenExternalUrl open;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
    final tappable = state.phase != AppUpdatePhase.installing;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(margin, topInset + 4, margin, 4),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: Semantics(
            button: tappable,
            child: TapRow(
              inkKey: UpdateNotice.noticeKey,
              onTap: tappable
                  ? () => showAppUpdateSheet(context, open: open)
                  : null,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(
                      child: DitherSwitcher(
                        key: UpdateNotice.noticeLabelSwitcherKey,
                        duration: const Duration(milliseconds: 300),
                        resizeDuration: const Duration(milliseconds: 200),
                        alignment: AlignmentDirectional.centerStart,
                        child: _NoticeLabel(
                          key: ValueKey(state.phase),
                          state: state,
                        ),
                      ),
                    ),
                    if (tappable) ...[
                      const SizedBox(width: 16),
                      const PixelIcon(PixelGlyph.arrowRight, size: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoticeLabel extends StatelessWidget {
  const _NoticeLabel({required this.state, super.key});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = appUpdatePhaseLabel(
      l10n,
      state,
      windows: theme.platform == TargetPlatform.windows,
      includeDownloadVersion: true,
    );
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      color: state.hasFailure
          ? scheme.error
          : state.phase == AppUpdatePhase.ready
          ? scheme.tertiary
          : scheme.onSurface,
    );
    final downloading = state.phase == AppUpdatePhase.downloading;
    if (downloading && state.totalBytes > 0) {
      return Text.rich(
        TextSpan(
          style: style,
          children: [
            DetailLayout.mixedDataSpan(
              label,
              sansStyle: style,
              monoStyle: style,
            ),
            const TextSpan(text: ' · '),
            TextSpan(
              text: '${state.progressPercent}%',
              style: DetailLayout.monoTelemetryStyle(
                style,
                color: scheme.tertiary,
              ),
            ),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final content = MixedDataText(
      downloading && state.receivedBytes > 0
          ? '$label · ${formatByteSize(l10n, state.receivedBytes)}'
          : label,
      sansStyle: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
    final shimmer = switch (state.phase) {
      AppUpdatePhase.verifying || AppUpdatePhase.installing => true,
      AppUpdatePhase.downloading =>
        state.totalBytes <= 0 && state.receivedBytes == 0,
      _ => false,
    };
    return shimmer ? PixelNoise.shimmer(child: content) : content;
  }
}

class _UpdateSheet extends StatefulWidget {
  const _UpdateSheet({
    required this.release,
    required this.windows,
    required this.open,
  });

  final AppRelease release;
  final bool windows;
  final OpenExternalUrl open;

  @override
  State<_UpdateSheet> createState() => _UpdateSheetState();
}

class _UpdateSheetState extends State<_UpdateSheet> {
  final _notesScroll = ScrollController();
  bool _openingExternal = false;
  AppVersion? _failedExternalVersion;

  @override
  void dispose() {
    _notesScroll.dispose();
    super.dispose();
  }

  Future<void> _openExternalDownload(AppRelease release) async {
    if (_openingExternal) return;
    setState(() {
      _openingExternal = true;
      _failedExternalVersion = null;
    });
    bool opened;
    try {
      opened = await widget.open(release.downloadUrl);
    } on Exception {
      opened = false;
    }
    if (!mounted) return;
    setState(() {
      _openingExternal = false;
      _failedExternalVersion = opened ? null : release.version;
    });
  }

  @override
  Widget build(BuildContext context) {
    final windows = widget.windows;
    final pinnedHeader = windows || !WindowSizeClass.of(context).isCompact;
    final inAppUpdate = context.read<AppUpdateCubit>().supportsInAppUpdate;
    return BlocBuilder<AppUpdateCubit, AppUpdateState>(
      builder: (context, state) {
        final currentRelease = state.availableRelease ?? widget.release;
        final header = _UpdateHeader(
          release: currentRelease,
          showCloseButton: pinnedHeader,
        );
        return SizedBox(
          key: UpdateNotice.sheetKey,
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pinnedHeader)
                Padding(
                  key: UpdateNotice.headerKey,
                  padding: const EdgeInsetsDirectional.fromSTEB(24, 16, 16, 16),
                  child: header,
                ),
              Flexible(
                child: Scrollbar(
                  controller: _notesScroll,
                  thumbVisibility: windows,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      key: UpdateNotice.notesScrollKey,
                      controller: _notesScroll,
                      padding: EdgeInsets.fromLTRB(
                        24,
                        pinnedHeader ? 0 : 4,
                        24,
                        24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!pinnedHeader) ...[
                            header,
                            const SizedBox(height: 16),
                          ],
                          _ReleaseNotes(notes: currentRelease.notes),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _UpdateFooter(
                release: currentRelease,
                state: state,
                windows: windows,
                inAppUpdate: inAppUpdate,
                openingExternal: _openingExternal,
                externalOpenFailed:
                    !inAppUpdate &&
                    _failedExternalVersion == currentRelease.version,
                onExternalDownload: () => _openExternalDownload(currentRelease),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UpdateHeader extends StatelessWidget {
  const _UpdateHeader({required this.release, required this.showCloseButton});

  final AppRelease release;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final version = Semantics(
      container: true,
      header: true,
      namesRoute: true,
      child: Text(
        '${release.version}',
        style: DetailLayout.monoTelemetryStyle(
          theme.textTheme.displaySmall?.copyWith(fontSize: 40, height: 1.1),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        if (showCloseButton)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: version),
              const CloseButton(),
            ],
          )
        else
          version,
        Semantics(
          header: true,
          child: Text(
            AppLocalizations.of(context).appUpdateWhatsNew,
            style: DetailLayout.sectionTitleStyle(theme),
          ),
        ),
      ],
    );
  }
}

class _UpdateFooter extends StatelessWidget {
  const _UpdateFooter({
    required this.release,
    required this.state,
    required this.windows,
    required this.inAppUpdate,
    required this.openingExternal,
    required this.externalOpenFailed,
    required this.onExternalDownload,
  });

  final AppRelease release;
  final AppUpdateState state;
  final bool windows;
  final bool inAppUpdate;
  final bool openingExternal;
  final bool externalOpenFailed;
  final VoidCallback onExternalDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final size = release.sizeBytes > 0
        ? formatByteSize(l10n, release.sizeBytes, compact: true)
        : null;
    final failure = _failureMessage(l10n, state.failure);
    final status = externalOpenFailed
        ? _FailureBanner(message: l10n.appUpdateOpenFailed)
        : switch (state.phase) {
            AppUpdatePhase.available when windows && size != null =>
              MixedDataText(
                size,
                sansStyle: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            AppUpdatePhase.installing => _BusyLabel(
              label: appUpdatePhaseLabel(l10n, state, windows: windows),
            ),
            AppUpdatePhase.failed || AppUpdatePhase.ready
                when failure != null =>
              _FailureBanner(message: failure),
            AppUpdatePhase.failed => _FailureBanner(
              message: l10n.appUpdateNoticeFailed,
            ),
            _ => null,
          };
    final actions = _actions(context, l10n, size);
    return DecoratedBox(
      key: UpdateNotice.footerKey,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: DitherSwitcher(
            duration: const Duration(milliseconds: 220),
            resizeDuration: const Duration(milliseconds: 200),
            alignment: AlignmentDirectional.bottomStart,
            child: ConstrainedBox(
              key: ValueKey((
                state.showsProgress ? AppUpdatePhase.downloading : state.phase,
                externalOpenFailed,
              )),
              constraints: const BoxConstraints(minHeight: 48),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final largeText = DetailLayout.isLargeText(context);
                  if (state.showsProgress) {
                    return _progressRow(
                      context,
                      actions.firstOrNull,
                      stacked: largeText && constraints.maxWidth < 420,
                    );
                  }
                  if (windows && !largeText && constraints.maxWidth >= 420) {
                    return Row(
                      children: [
                        Expanded(child: status ?? const SizedBox.shrink()),
                        if (actions.isNotEmpty) ...[
                          const SizedBox(width: 16),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 8,
                            children: actions,
                          ),
                        ],
                      ],
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      ?status,
                      if (actions.isNotEmpty)
                        windows
                            ? OverflowBar(
                                alignment: MainAxisAlignment.end,
                                overflowAlignment: OverflowBarAlignment.end,
                                spacing: 8,
                                overflowSpacing: 8,
                                children: actions,
                              )
                            : Row(
                                spacing: 8,
                                children: [
                                  if (actions.length > 1) actions.first,
                                  Expanded(child: actions.last),
                                ],
                              ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AppLocalizations l10n,
    String? size,
  ) {
    final cubit = context.read<AppUpdateCubit>();
    final textStyle = TextButton.styleFrom(minimumSize: const Size(48, 48));
    if (state.phase == AppUpdatePhase.downloading) {
      return [
        TextButton(
          key: UpdateNotice.cancelDownloadKey,
          onPressed: state.cancelling ? null : cubit.cancelDownload,
          style: busyButtonStyle(busy: state.cancelling, base: textStyle),
          child: BusyButtonChild(
            l10n.appUpdateCancelDownload,
            busy: state.cancelling,
          ),
        ),
      ];
    }
    final label = switch (state.phase) {
      AppUpdatePhase.available => l10n.appUpdateDownload,
      AppUpdatePhase.failed =>
        state.failure == AppUpdateFailureKind.invalidFile
            ? l10n.appUpdateDownloadAgain
            : l10n.appUpdateRetry,
      AppUpdatePhase.ready =>
        windows
            ? l10n.appUpdateRestartAndUpdate
            : state.failure == AppUpdateFailureKind.install
            ? l10n.appUpdateRetryInstall
            : l10n.appUpdateInstall,
      _ => null,
    };
    if (label == null) return const [];
    final installing = inAppUpdate && state.phase == AppUpdatePhase.ready;
    return [
      if (!installing)
        TextButton(
          key: UpdateNotice.laterKey,
          onPressed: () async {
            final route = ModalRoute.of(context);
            await cubit.dismiss();
            if (context.mounted && route?.isCurrent == true) {
              Navigator.of(context).pop();
            }
          },
          style: textStyle,
          child: Text(l10n.appUpdateLater),
        ),
      FilledButton(
        key: installing
            ? UpdateNotice.installKey
            : UpdateNotice.downloadActionKey,
        onPressed: installing
            ? cubit.install
            : inAppUpdate
            ? cubit.download
            : openingExternal
            ? null
            : onExternalDownload,
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child:
            !windows && state.phase == AppUpdatePhase.available && size != null
            ? PixelSeparatedText('$label · $size', textAlign: TextAlign.center)
            : Text(label, textAlign: TextAlign.center),
      ),
    ];
  }

  Widget _progressRow(
    BuildContext context,
    Widget? cancel, {
    required bool stacked,
  }) {
    final progress = _DownloadProgress(state: state, windows: windows);
    final control = AnimatedSize(
      duration: motionDuration(context, const Duration(milliseconds: 200)),
      alignment: AlignmentDirectional.centerEnd,
      child: cancel == null
          ? const SizedBox.shrink()
          : Padding(
              padding: stacked
                  ? const EdgeInsets.only(top: 8)
                  : const EdgeInsetsDirectional.only(start: 16),
              child: cancel,
            ),
    );
    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          progress,
          Align(alignment: AlignmentDirectional.centerEnd, child: control),
        ],
      );
    }
    // Anchor the bar if the byte count wraps to more lines than the status.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: progress,
          ),
        ),
        control,
      ],
    );
  }
}

class AppUpdateProgressBar extends StatelessWidget {
  const AppUpdateProgressBar({required this.state, super.key});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    if (state.phase == AppUpdatePhase.verifying) {
      return const SegmentedBar(value: 1, height: 6);
    }
    return state.totalBytes > 0
        ? SegmentedBar(value: state.progress, height: 6)
        : const BlockSpinner(height: 6);
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state, required this.windows});

  final AppUpdateState state;
  final bool windows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final received = formatByteSize(l10n, state.receivedBytes);
    final knownTotal = state.totalBytes > 0;
    final label = [
      if (windows || (!knownTotal && state.receivedBytes == 0))
        l10n.appUpdateDownloading,
      if (knownTotal)
        l10n.appUpdateProgress(
          received,
          formatByteSize(l10n, state.totalBytes, compact: true),
        )
      else if (state.receivedBytes > 0)
        received,
      if (!windows && knownTotal) '${state.progressPercent}%',
    ].join(' · ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        if (state.phase == AppUpdatePhase.verifying)
          _BusyLabel(label: l10n.appUpdateNoticeVerifying)
        else
          MixedDataText(
            label,
            sansStyle: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        AppUpdateProgressBar(state: state),
      ],
    );
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: PixelNoise.shimmer(
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontFamily: DetailLayout.sansFont,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ReleaseNotes extends StatelessWidget {
  const _ReleaseNotes({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final blocks = _releaseNoteBlocks(notes);
    if (blocks.isEmpty) {
      return Text(
        l10n.appUpdateNoNotes,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: DetailLayout.sansFont,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, block) in blocks.indexed) ...[
          if (index > 0)
            SizedBox(height: block.kind == _NoteKind.heading ? 20 : 12),
          _NoteBlock(block: block),
        ],
      ],
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.block});

  final _NoteBlockData block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: DetailLayout.sansFont,
      height: 1.45,
    );
    if (block.kind == _NoteKind.heading) {
      return Semantics(
        header: true,
        child: Text(
          block.text,
          style: DetailLayout.sectionTitleStyle(theme).copyWith(fontSize: 14),
        ),
      );
    }
    final marker = block.marker;
    if (marker == null) return Text(block.text, style: style);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: 8,
      children: [
        Text(marker, style: DetailLayout.monoTelemetryStyle(style)),
        Expanded(child: Text(block.text, style: style)),
      ],
    );
  }
}

enum _NoteKind { heading, paragraph, bullet }

final class _NoteBlockData {
  const _NoteBlockData(this.kind, this.text, {this.marker});

  final _NoteKind kind;
  final String text;
  final String? marker;
}

final _noteHeading = RegExp(r'^#{1,6}\s+(.+)$');
final _noteBullet = RegExp(r'^([-*+]|\d+\.)\s+(.+)$');

List<_NoteBlockData> _releaseNoteBlocks(String markdown) {
  final blocks = <_NoteBlockData>[];
  final paragraph = <String>[];
  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(
      _NoteBlockData(_NoteKind.paragraph, _plainMarkdown(paragraph.join(' '))),
    );
    paragraph.clear();
  }

  for (final rawLine in markdown.replaceAll('\r', '').split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }
    final heading = _noteHeading.firstMatch(line);
    final bullet = _noteBullet.firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(
        _NoteBlockData(_NoteKind.heading, _plainMarkdown(heading.group(1)!)),
      );
    } else if (bullet != null) {
      flushParagraph();
      final prefix = bullet.group(1)!;
      blocks.add(
        _NoteBlockData(
          _NoteKind.bullet,
          _plainMarkdown(bullet.group(2)!),
          marker: prefix.endsWith('.') ? prefix : '•',
        ),
      );
    } else {
      paragraph.add(line);
    }
  }
  flushParagraph();
  return blocks;
}

String _plainMarkdown(String text) => text
    .replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]+\)'),
      (match) => match.group(1)!,
    )
    .replaceAll(RegExp(r'(\*\*|__|~~|[*_`])'), '');

String? _failureMessage(AppLocalizations l10n, AppUpdateFailureKind? failure) =>
    switch (failure) {
      AppUpdateFailureKind.network => l10n.appUpdateFailureNetwork,
      AppUpdateFailureKind.invalidFile => l10n.appUpdateFailureInvalidFile,
      AppUpdateFailureKind.storage => l10n.appUpdateFailureStorage,
      AppUpdateFailureKind.install => l10n.appUpdateFailureInstall,
      AppUpdateFailureKind.permission => l10n.appUpdateFailurePermission,
      AppUpdateFailureKind.cancelled || null => null,
    };

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: DetailLayout.sansFont,
          color: theme.colorScheme.error,
          height: 1.4,
        ),
      ),
    );
  }
}
