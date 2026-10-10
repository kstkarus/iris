import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/marked_tab.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';

/// Top-level shell with adaptive navigation.
///
/// * compact: a row of text tabs along the bottom edge;
/// * medium and wider: a top bar with the app's mark and the sections in
///   small text, which Ctrl+1…4 also switch.
///
/// The navigation stays small on purpose: each page brings its own large
/// headline, and the contrast between the two carries the hierarchy.
class AppShellPage extends StatelessWidget {
  const AppShellPage({required this.navigationShell, super.key});

  static const navigationBarKey = Key('app_shell_navigation_bar');
  static const navigationRailKey = Key('app_shell_navigation_rail');

  final StatefulNavigationShell navigationShell;

  void _select(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [
      l10n.navigationCatalog,
      l10n.navigationSavedTorrents,
      l10n.navigationDownloads,
      l10n.navigationProfile,
    ];

    if (WindowSizeClass.of(context).isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: _BottomTabs(
          key: navigationBarKey,
          labels: labels,
          selectedIndex: navigationShell.currentIndex,
          onSelected: _select,
        ),
      );
    }

    return CallbackShortcuts(
      bindings: {
        for (final (index, key) in _sectionKeys.indexed)
          SingleActivator(key, control: true): () => _select(index),
      },
      child: Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              key: navigationRailKey,
              appName: l10n.appName,
              labels: labels,
              selectedIndex: navigationShell.currentIndex,
              onSelected: _select,
            ),
            Expanded(child: navigationShell),
          ],
        ),
      ),
    );
  }
}

const _sectionKeys = [
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
];

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appName,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  static const height = 64.0;

  final String appName;
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final margin = WindowSizeClass.of(context).pageMargin;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: height,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: margin),
            // On the page frame: the mark over the content's left edge,
            // the sections in the middle.
            child: MaxWidthBox(
              maxWidth: AdaptiveContentWidth.page,
              alignment: Alignment.center,
              // The row takes the frame's width, and scrolls sideways only
              // when the mark and the sections need more (large text).
              // IntrinsicWidth gives its Expanded and Spacer a finite width.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  // Stops at the ends, so the bar does not rubber-band on iOS.
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: IntrinsicWidth(
                      child: Row(
                        children: [
                          Expanded(
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: _Wordmark(appName: appName),
                            ),
                          ),
                          for (var index = 0; index < labels.length; index++)
                            MarkedTab(
                              label: labels[index],
                              selected: index == selectedIndex,
                              onTap: () => onSelected(index),
                            ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.appName});

  final String appName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: appName,
      child: ExcludeSemantics(
        child: Row(
          children: [
            PixelIcon(
              PixelGlyph.iris,
              size: 21,
              color: theme.colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Text(
              appName.toLowerCase(),
              style: theme.textTheme.titleLarge?.copyWith(letterSpacing: 3),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            children: [
              Row(
                children: [
                  for (var index = 0; index < labels.length; index++)
                    Expanded(
                      child: _BottomTab(
                        label: labels[index],
                        selected: index == selectedIndex,
                        onTap: () => onSelected(index),
                      ),
                    ),
                ],
              ),
              // One indicator that travels to the chosen tab.
              AnimatedAlign(
                duration: _markerDuration(context),
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  labels.length < 2
                      ? 0
                      : -1 + 2 * selectedIndex / (labels.length - 1),
                  -1,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / labels.length,
                  child: Container(height: 2, color: scheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: 2),
            Expanded(
              child: Center(
                // Very large text shrinks a label that would not fit, a
                // little, rather than cutting the word off; at usual sizes
                // every label fits as it is.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Duration _markerDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 220);
