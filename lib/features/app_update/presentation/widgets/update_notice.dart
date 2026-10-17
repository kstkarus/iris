import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/domain/entities/app_update_failure.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_state.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/byte_size_formatter.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';
import 'package:iris/shared/widgets/dither_transition.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';
import 'package:iris/shared/widgets/tap_row.dart';

/// Opens [url] outside the app; false when nothing could.
typedef OpenExternalUrl = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// An update strip above [child]. Android opens an in-app release sheet;
/// platforms without in-app updates keep their existing external download.
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
  static const downloadKey = Key('update_notice_download');
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
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else {
      _controller.animateTo(target);
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
                        inAppUpdate: widget.inAppUpdate,
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
    required this.inAppUpdate,
    required this.open,
    required this.topInset,
  });

  final AppUpdateState state;
  final bool inAppUpdate;
  final OpenExternalUrl open;
  final double topInset;

  Future<void> _downloadExternally(BuildContext context) async {
    final failed = AppLocalizations.of(context).appUpdateOpenFailed;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await open(state.release!.downloadUrl);
    if (!opened) messenger?.showSnackBar(SnackBar(content: Text(failed)));
  }

  void _showSheet(BuildContext context) {
    final cubit = context.read<AppUpdateCubit>();
    showAdaptiveSheet<void>(
      context: context,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _UpdateSheet(release: state.release!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
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
          child: inAppUpdate
              ? Semantics(
                  button: true,
                  child: TapRow(
                    inkKey: UpdateNotice.noticeKey,
                    onTap: () => _showSheet(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: MediaQuery.textScalerOf(
                                context,
                              ).scale(24),
                              child: DitherSwitcher(
                                key: UpdateNotice.noticeLabelSwitcherKey,
                                duration: const Duration(milliseconds: 300),
                                expand: true,
                                child: Align(
                                  key: ValueKey(state.phase),
                                  alignment: Alignment.centerLeft,
                                  child: _NoticeLabel(state: state),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const PixelIcon(PixelGlyph.arrowRight, size: 16),
                        ],
                      ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).appUpdateAvailable('${state.release!.version}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: UpdateNotice.laterKey,
                      onPressed: () => context.read<AppUpdateCubit>().dismiss(),
                      child: Text(AppLocalizations.of(context).appUpdateLater),
                    ),
                    TextButton(
                      key: UpdateNotice.downloadKey,
                      onPressed: () => _downloadExternally(context),
                      child: Text(
                        AppLocalizations.of(context).appUpdateDownload,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _NoticeLabel extends StatelessWidget {
  const _NoticeLabel({required this.state});

  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = Theme.of(context).colorScheme.tertiary;
    if (state.phase == AppUpdatePhase.downloading) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(text: l10n.appUpdateNoticeDownloading),
            if (state.totalBytes > 0) ...[
              const TextSpan(text: ' · '),
              TextSpan(
                text: '${(state.progress * 100).round()}%',
                style: TextStyle(color: color),
              ),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    final text = switch (state.phase) {
      AppUpdatePhase.available => l10n.appUpdateNoticeAvailable(
        '${state.release!.version}',
      ),
      AppUpdatePhase.verifying => l10n.appUpdateNoticeVerifying,
      AppUpdatePhase.ready => l10n.appUpdateNoticeReady,
      AppUpdatePhase.installing => l10n.appUpdateNoticeInstalling,
      AppUpdatePhase.failed => l10n.appUpdateNoticeFailed,
      AppUpdatePhase.downloading => throw StateError('handled above'),
    };
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}

class _UpdateSheet extends StatelessWidget {
  const _UpdateSheet({required this.release});

  final AppRelease release;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AppUpdateCubit, AppUpdateState>(
        builder: (context, state) {
          final l10n = AppLocalizations.of(context);
          final theme = Theme.of(context);
          final failure = _failureMessage(l10n, state.failure);
          return SizedBox(
            key: UpdateNotice.sheetKey,
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      primary: true,
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${release.version}',
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontSize: 40,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.appUpdateWhatsNew,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                            ),
                          ),
                          if (failure != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              failure,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          _ReleaseNotes(notes: release.notes),
                        ],
                      ),
                    ),
                  ),
                ),
                _UpdateFooter(release: release, state: state),
              ],
            ),
          );
        },
      );
}

class _UpdateFooter extends StatelessWidget {
  const _UpdateFooter({required this.release, required this.state});

  final AppRelease release;
  final AppUpdateState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            height: largeText ? 120 : 48,
            child: DitherSwitcher(
              expand: true,
              child: _footerContent(context, state, release),
            ),
          ),
        ),
      ),
    );
  }

  Widget _footerContent(
    BuildContext context,
    AppUpdateState state,
    AppRelease release,
  ) {
    final l10n = AppLocalizations.of(context);
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return switch (state.phase) {
      AppUpdatePhase.available || AppUpdatePhase.failed => Row(
        key: ValueKey(state.phase),
        children: [
          TextButton(
            onPressed: () => _dismiss(context),
            style: _textButtonStyle(largeText),
            child: Text(l10n.appUpdateLater),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: FilledButton(
              key: UpdateNotice.downloadActionKey,
              onPressed: () => context.read<AppUpdateCubit>().download(),
              style: _filledButtonStyle(largeText),
              child: Text(
                state.phase == AppUpdatePhase.failed
                    ? l10n.appUpdateRetry
                    : _downloadLabel(l10n, release),
                maxLines: largeText ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      AppUpdatePhase.downloading =>
        largeText
            ? Column(
                key: ValueKey(state.phase),
                children: [
                  Expanded(
                    child: _DownloadProgress(state: state, largeText: true),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: UpdateNotice.cancelDownloadKey,
                      onPressed: () =>
                          context.read<AppUpdateCubit>().cancelDownload(),
                      style: _textButtonStyle(false),
                      child: Text(l10n.appUpdateCancelDownload),
                    ),
                  ),
                ],
              )
            : Row(
                key: ValueKey(state.phase),
                children: [
                  Expanded(child: _DownloadProgress(state: state)),
                  const SizedBox(width: 16),
                  TextButton(
                    key: UpdateNotice.cancelDownloadKey,
                    onPressed: () =>
                        context.read<AppUpdateCubit>().cancelDownload(),
                    style: _textButtonStyle(false),
                    child: Text(l10n.appUpdateCancelDownload),
                  ),
                ],
              ),
      AppUpdatePhase.verifying =>
        largeText
            ? Column(
                key: ValueKey(state.phase),
                children: [
                  Expanded(
                    child: _BusyLabel(label: l10n.appUpdateNoticeVerifying),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      key: UpdateNotice.cancelDownloadKey,
                      onPressed: () =>
                          context.read<AppUpdateCubit>().cancelDownload(),
                      style: _textButtonStyle(false),
                      child: Text(l10n.appUpdateCancelDownload),
                    ),
                  ),
                ],
              )
            : Row(
                key: ValueKey(state.phase),
                children: [
                  Expanded(
                    child: _BusyLabel(label: l10n.appUpdateNoticeVerifying),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    key: UpdateNotice.cancelDownloadKey,
                    onPressed: () =>
                        context.read<AppUpdateCubit>().cancelDownload(),
                    style: _textButtonStyle(false),
                    child: Text(l10n.appUpdateCancelDownload),
                  ),
                ],
              ),
      AppUpdatePhase.installing => _BusyLabel(
        key: ValueKey(state.phase),
        label: l10n.appUpdateNoticeInstalling,
      ),
      AppUpdatePhase.ready => KeyedSubtree(
        key: ValueKey(state.phase),
        child: FilledButton(
          key: UpdateNotice.installKey,
          onPressed: () => context.read<AppUpdateCubit>().install(),
          style: _filledButtonStyle(largeText),
          child: Text(
            l10n.appUpdateInstall,
            maxLines: largeText ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    };
  }

  Future<void> _dismiss(BuildContext context) async {
    final navigator = Navigator.of(context);
    await context.read<AppUpdateCubit>().dismiss();
    if (context.mounted) navigator.pop();
  }

  String _downloadLabel(AppLocalizations l10n, AppRelease release) =>
      release.sizeBytes > 0
      ? '${l10n.appUpdateDownload} · ${formatByteSize(l10n, release.sizeBytes, compact: true)}'
      : l10n.appUpdateDownload;

  Size _buttonSize(bool largeText) => Size(64, largeText ? 80 : 48);

  ButtonStyle _textButtonStyle(bool largeText) {
    final size = _buttonSize(largeText);
    return TextButton.styleFrom(
      minimumSize: size,
      maximumSize: Size(double.infinity, size.height),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: largeText ? 8 : 0,
      ),
    );
  }

  ButtonStyle _filledButtonStyle(bool largeText) {
    final size = _buttonSize(largeText);
    return FilledButton.styleFrom(
      minimumSize: size,
      maximumSize: Size(double.infinity, size.height),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: largeText ? 8 : 0,
      ),
    );
  }
}

class _DownloadProgress extends StatelessWidget {
  const _DownloadProgress({required this.state, this.largeText = false});

  final AppUpdateState state;
  final bool largeText;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final percent = state.totalBytes > 0
        ? '${(state.progress * 100).round()}%'
        : null;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: state.totalBytes > 0
                    ? l10n.appUpdateProgress(
                        formatByteSize(l10n, state.receivedBytes),
                        formatByteSize(l10n, state.totalBytes, compact: true),
                      )
                    : formatByteSize(l10n, state.receivedBytes),
              ),
              if (percent != null) ...[
                const TextSpan(text: ' · '),
                TextSpan(
                  text: percent,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ],
            ],
          ),
          maxLines: largeText ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedBar(value: state.progress, height: 4),
      ],
    );
  }
}

class _BusyLabel extends StatelessWidget {
  const _BusyLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      label,
      maxLines: 2,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
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
      return Text(l10n.appUpdateNoNotes, style: theme.textTheme.bodyMedium);
    }
    final children = <Widget>[];
    var hasContent = false;
    for (final block in blocks) {
      if (block.kind == _NoteKind.heading && hasContent) {
        children.addAll(const [
          SizedBox(height: 16),
          SegmentedRule(),
          SizedBox(height: 16),
        ]);
      } else if (hasContent) {
        children.add(const SizedBox(height: 8));
      }
      children.add(_NoteBlock(block: block));
      hasContent = true;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.block});

  final _NoteBlockData block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = switch (block.kind) {
      _NoteKind.heading => theme.textTheme.titleSmall,
      _NoteKind.paragraph => theme.textTheme.bodyMedium,
      _NoteKind.bullet => theme.textTheme.bodyMedium,
    };
    if (block.kind != _NoteKind.bullet) {
      return Text(block.text, style: style);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('•', style: style),
        const SizedBox(width: 8),
        Expanded(child: Text(block.text, style: style)),
      ],
    );
  }
}

enum _NoteKind { heading, paragraph, bullet }

final class _NoteBlockData {
  const _NoteBlockData(this.kind, this.text);

  final _NoteKind kind;
  final String text;
}

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
    final heading = RegExp(r'^#{1,6}\s+(.+)$').firstMatch(line);
    final bullet = RegExp(r'^(?:[-*+]|\d+\.)\s+(.+)$').firstMatch(line);
    if (heading != null) {
      flushParagraph();
      blocks.add(
        _NoteBlockData(_NoteKind.heading, _plainMarkdown(heading.group(1)!)),
      );
    } else if (bullet != null) {
      flushParagraph();
      blocks.add(
        _NoteBlockData(_NoteKind.bullet, _plainMarkdown(bullet.group(1)!)),
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
