import 'package:flutter/material.dart';

import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/settings/presentation/widgets/settings_body.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/headline_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({this.openExternalUrl, super.key});

  final OpenExternalUrl? openExternalUrl;

  @override
  Widget build(BuildContext context) {
    final title = AppLocalizations.of(context).settingsTitle;
    final compact = WindowSizeClass.of(context).isCompact;
    return HeadlinePage(
      title: title,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: PageFrame.subPage(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 864),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DetailHeroTitles(
                      title: title,
                      maxSize: compact ? 48 : 72,
                      minSize: 18,
                      maxLines: 1,
                    ),
                    SizedBox(height: compact ? 8 : 16),
                    SettingsBody(openExternalUrl: openExternalUrl),
                    const SizedBox(height: 24),
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
