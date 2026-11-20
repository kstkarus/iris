import 'package:flutter/material.dart';

import 'package:iris/features/app_update/presentation/widgets/update_notice.dart';
import 'package:iris/features/settings/presentation/widgets/animejoy_account_section.dart';
import 'package:iris/features/settings/presentation/widgets/settings_body.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/dither_switcher.dart';

Future<void> showSettingsDialog(BuildContext context) async {
  // Keep the live app theme so Appearance previews changes inside the dialog.
  final route = DialogRoute<bool>(
    context: context,
    traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
    animationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => const _SettingsDialog(),
  );
  Navigator.of(context, rootNavigator: true).push(route);
  if (await route.completed == true && context.mounted) {
    await showAppUpdateSheet(context);
  }
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog();

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  bool _showSignIn = false;

  void _backToSettings() => setState(() => _showSignIn = false);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Dialog(
      clipBehavior: Clip.hardEdge,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      constraints: BoxConstraints(
        maxWidth: 648,
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(28, 12, 16, 4),
            child: Row(
              children: [
                if (_showSignIn) ...[
                  BackButton(onPressed: _backToSettings),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    namesRoute: true,
                    child: Text(
                      _showSignIn
                          ? l10n.settingsAnimejoySignInTitle
                          : l10n.settingsTitle,
                      style: theme.dialogTheme.titleTextStyle?.copyWith(
                        fontSize: 24,
                        wordSpacing: -3.6,
                      ),
                    ),
                  ),
                ),
                const CloseButton(),
              ],
            ),
          ),
          Flexible(
            child: DitherSwitcher(
              duration: const Duration(milliseconds: 220),
              resizeDuration: const Duration(milliseconds: 200),
              child: SingleChildScrollView(
                key: ValueKey(_showSignIn),
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                child: _showSignIn
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: AnimejoySignInForm(onDone: _backToSettings),
                      )
                    : SettingsBody(
                        onAnimejoySignIn: () =>
                            setState(() => _showSignIn = true),
                        onOpenUpdate: () =>
                            Navigator.of(context).maybePop(true),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
