import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Room between a popover and its button, and the window's edges.
const _anchorGap = 12.0;
const _edgeMargin = 16.0;

/// Shows [builder] as a popover of [anchor], the button that opened it:
/// above the button where there is more room above, below it otherwise,
/// ending in line with its right edge. The video stays in view undimmed; a
/// click outside or Escape closes it.
///
/// [width] is the popover's width where the window has room for it.
Future<T?> showPlayerPopover<T>({
  required BuildContext anchor,
  required WidgetBuilder builder,
  required double width,
  String? semanticsLabel,
}) {
  final navigator = Navigator.of(anchor, rootNavigator: true);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final button = anchor.findRenderObject()! as RenderBox;
  final anchorRect =
      button.localToGlobal(Offset.zero, ancestor: overlay) & button.size;
  final above = anchorRect.top >= overlay.size.height - anchorRect.bottom;
  return navigator.push(
    _PlayerPopoverRoute<T>(
      anchorRect: anchorRect,
      above: above,
      width: width,
      builder: builder,
      semanticsLabel: semanticsLabel,
      barrierLabel: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
      // The player's own theme lies above the root navigator's routes.
      themes: InheritedTheme.capture(from: anchor, to: navigator.context),
    ),
  );
}

/// Whether [context] is inside a popover of the player. The popover's
/// button names it, so its content can leave out a title.
bool isInPlayerPopover(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_PopoverScope>() != null;

class _PopoverScope extends InheritedWidget {
  const _PopoverScope({required super.child});

  @override
  bool updateShouldNotify(_PopoverScope oldWidget) => false;
}

class _PlayerPopoverRoute<T> extends PopupRoute<T> {
  _PlayerPopoverRoute({
    required this.anchorRect,
    required this.above,
    required this.width,
    required this.builder,
    required this.semanticsLabel,
    required this.barrierLabel,
    required this.themes,
  });

  final Rect anchorRect;
  final bool above;
  final double width;
  final WidgetBuilder builder;
  final String? semanticsLabel;
  final CapturedThemes themes;
  Size? _openedIn;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 160);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 110);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final mediaQuery = MediaQuery.of(context);
    // Its button moves with a resized window; a popover left behind would
    // point at nothing, so it closes instead.
    final openedIn = _openedIn ??= mediaQuery.size;
    if (mediaQuery.size != openedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (isActive) navigator?.removeRoute(this);
      });
    }
    return CustomSingleChildLayout(
      delegate: _PopoverLayout(
        anchor: anchorRect,
        above: above,
        width: width,
        safeArea: mediaQuery.padding,
      ),
      // The popover sits clear of the system bars already.
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: themes.wrap(
          _PopoverScope(
            child: Builder(
              builder: (context) => _PopoverSurface(
                semanticsLabel: semanticsLabel,
                child: builder(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final faded = FadeTransition(opacity: curved, child: child);
    // Reduced motion keeps the fade and drops the travel.
    if (MediaQuery.disableAnimationsOf(context)) return faded;
    // It comes out of its button: up from a button below, down from one above.
    final travel = above ? 8.0 : -8.0;
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, travel * (1 - curved.value)),
        child: child,
      ),
      child: faded,
    );
  }
}

class _PopoverSurface extends StatelessWidget {
  const _PopoverSurface({required this.semanticsLabel, required this.child});

  final String? semanticsLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = theme.dialogTheme;
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: semanticsLabel,
      child: Material(
        key: const Key('player_popover'),
        color: dialogTheme.backgroundColor ?? theme.colorScheme.surface,
        shape:
            dialogTheme.shape ?? Border.all(color: theme.colorScheme.outline),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class _PopoverLayout extends SingleChildLayoutDelegate {
  const _PopoverLayout({
    required this.anchor,
    required this.above,
    required this.width,
    required this.safeArea,
  });

  final Rect anchor;
  final bool above;
  final double width;
  final EdgeInsets safeArea;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final room = constraints.maxWidth - safeArea.horizontal - 2 * _edgeMargin;
    final childWidth = math.max(0.0, math.min(width, room));
    final height = above
        ? anchor.top - _anchorGap - safeArea.top - _edgeMargin
        : constraints.maxHeight -
              anchor.bottom -
              _anchorGap -
              safeArea.bottom -
              _edgeMargin;
    return BoxConstraints.tightFor(
      width: childWidth,
    ).copyWith(maxHeight: math.max(0.0, height));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final minLeft = safeArea.left + _edgeMargin;
    final maxLeft = math.max(
      minLeft,
      size.width - safeArea.right - _edgeMargin - childSize.width,
    );
    final left = (anchor.right - childSize.width).clamp(minLeft, maxLeft);
    final top = above
        ? anchor.top - _anchorGap - childSize.height
        : anchor.bottom + _anchorGap;
    return Offset(left, top);
  }

  @override
  bool shouldRelayout(_PopoverLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      above != oldDelegate.above ||
      width != oldDelegate.width ||
      safeArea != oldDelegate.safeArea;
}
