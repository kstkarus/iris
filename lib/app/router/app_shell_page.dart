import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';

/// Top-level shell with adaptive navigation.
///
/// * compact: bottom [NavigationBar];
/// * medium / expanded: [NavigationRail] with labels under icons;
/// * large / extra-large: extended [NavigationRail] with labels beside icons.
class AppShellPage extends StatelessWidget {
  const AppShellPage({required this.navigationShell, super.key});

  static const navigationBarKey = Key('app_shell_navigation_bar');
  static const navigationRailKey = Key('app_shell_navigation_rail');

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations(AppLocalizations.of(context));
    final sizeClass = WindowSizeClass.of(context);

    if (sizeClass.isCompact) {
      return Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          key: navigationBarKey,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      );
    }

    final isExtended = sizeClass.isAtLeast(WindowSizeClass.large);

    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              key: navigationRailKey,
              extended: isExtended,
              labelType: isExtended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              groupAlignment: -1,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          ),
          Expanded(child: navigationShell),
        ],
      ),
    );
  }
}

List<_ShellDestination> _destinations(AppLocalizations l10n) {
  return [
    _ShellDestination(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore_rounded,
      label: l10n.navigationCatalog,
    ),
    _ShellDestination(
      icon: Icons.bookmarks_outlined,
      selectedIcon: Icons.bookmarks,
      label: l10n.navigationSavedTorrents,
    ),
    _ShellDestination(
      icon: Icons.download_outlined,
      selectedIcon: Icons.download_rounded,
      label: l10n.navigationDownloads,
    ),
  ];
}

class _ShellDestination {
  const _ShellDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
