import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:iris/features/app_update/domain/entities/app_release.dart';
import 'package:iris/features/app_update/presentation/cubit/app_update_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

/// Opens [url] outside the app; false when nothing could.
typedef OpenExternalUrl = Future<bool> Function(Uri url);

Future<bool> _openInBrowser(Uri url) =>
    launchUrl(url, mode: LaunchMode.externalApplication);

/// A strip that says a newer version is out, with Download (the browser
/// fetches the build, and the system installs it as usual) and Later
/// (not offered again until a newer one). Nothing without an update: it
/// opens and closes in place, so the pages beside it give and take the
/// room smoothly.
class UpdateNotice extends StatelessWidget {
  const UpdateNotice({this.open = _openInBrowser, super.key});

  static const downloadKey = Key('update_notice_download');
  static const laterKey = Key('update_notice_later');

  final OpenExternalUrl open;

  @override
  Widget build(BuildContext context) {
    // Shells built without the check (as in tests) offer nothing.
    final release = context.watch<AppUpdateCubit?>()?.state;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: release == null
          ? const SizedBox(width: double.infinity)
          : _Strip(release: release, open: open),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.release, required this.open});

  final AppRelease release;
  final OpenExternalUrl open;

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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        border: Border.symmetric(
          horizontal: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
    );
  }
}
