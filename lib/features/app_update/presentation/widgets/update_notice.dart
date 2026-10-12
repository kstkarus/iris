import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

/// Opens [url] outside the app; false when nothing could.
typedef OpenExternalUrl = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// A strip above [child] that says a newer version is out, with Download
/// (the browser fetches the build, and the system installs it as usual) and
/// Later (not offered again until a newer one). Without an update it is
/// nothing.
///
/// At the top of the screen the strip runs up under the status bar and
/// takes the top inset over from [child], which keeps its content where it
/// was: as the strip opens or closes, the inset passes between the two, so
/// nothing below jumps.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({
    required this.child,
    this.open = _openInBrowser,
    super.key,
  });

  static const downloadKey = Key('update_notice_download');
  static const laterKey = Key('update_notice_later');

  final Widget child;
  final OpenExternalUrl open;

  @override
  Widget build(BuildContext context) => _DevelopingNotice(
    // Shells built without the check (as in tests) offer nothing.
    release: context.watch<AppUpdateCubit?>()?.state,
    open: open,
    child: child,
  );
}

/// Opens the strip like a section that arrives late: the space first, then
/// the strip develops in it cell by cell. Later runs it backwards: the strip
/// dissolves, then gives its height back.
class _DevelopingNotice extends StatefulWidget {
  const _DevelopingNotice({
    required this.release,
    required this.open,
    required this.child,
  });

  final AppRelease? release;
  final OpenExternalUrl open;
  final Widget child;

  @override
  State<_DevelopingNotice> createState() => _DevelopingNoticeState();
}

class _DevelopingNoticeState extends State<_DevelopingNotice>
    with SingleTickerProviderStateMixin {
  /// Half for the space, half for developing, as a collapsing switch.
  late final _controller = AnimationController(
    vsync: this,
    duration: DitherTransition.duration * 2,
    // A shell rebuilt with the release out (the window resized) shows it.
    value: widget.release == null ? 0 : 1,
  );

  /// The release shown, kept while the strip closes after Later.
  late AppRelease? _shown = widget.release;

  @override
  void didUpdateWidget(_DevelopingNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    final release = widget.release;
    if (release != null) _shown = release;
    if ((release == null) == (oldWidget.release == null)) return;
    final target = release == null ? 0.0 : 1.0;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = target;
    } else {
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
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
        final progress = _controller.value;
        final opened = Curves.easeInOut.transform(
          (progress * 2).clamp(0.0, 1.0),
        );
        final developed = (progress * 2 - 1).clamp(0.0, 1.0);
        final shown = _shown;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (opened > 0 && shown != null)
              ClipRect(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  heightFactor: opened,
                  child: IgnorePointer(
                    ignoring: developed < 1,
                    child: BayerMasked(
                      open: (developed * BayerMask.steps).round(),
                      child: _Strip(
                        release: shown,
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
    required this.release,
    required this.open,
    required this.topInset,
  });

  final AppRelease release;
  final OpenExternalUrl open;
  final double topInset;

  Future<void> _download(BuildContext context) async {
    final failed = AppLocalizations.of(context).appUpdateOpenFailed;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final opened = await open(release.downloadUrl);
    if (!opened) {
      messenger?.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      // On the page frame, like the content below and the top bar above.
      child: Padding(
        padding: EdgeInsets.fromLTRB(margin, topInset + 4, margin, 4),
        child: MaxWidthBox(
          maxWidth: AdaptiveContentWidth.page,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.appUpdateAvailable('${release.version}'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                key: UpdateNotice.laterKey,
                onPressed: () => context.read<AppUpdateCubit>().dismiss(),
                child: Text(l10n.appUpdateLater),
              ),
              TextButton(
                key: UpdateNotice.downloadKey,
                onPressed: () => _download(context),
                child: Text(l10n.appUpdateDownload),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
