import 'package:flutter/material.dart';

import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/dither_transition.dart';

/// A scrolling list whose rows come and go cell by cell: a row added after
/// the list first shows opens its space, then develops in it; a removed
/// row dissolves, then gives its height back, so the rows around it slide
/// instead of jumping. Rows are told apart by [keyOf].
class DitherList<T> extends StatefulWidget {
  const DitherList({
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.padding,
    super.key,
  });

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  State<DitherList<T>> createState() => _DitherListState<T>();
}

class _DitherListState<T> extends State<DitherList<T>> {
  /// The rows shown: the current items, and removed ones still leaving at
  /// the places they had.
  late List<_Entry<T>> _entries = [
    for (final item in widget.items)
      _Entry(item, widget.keyOf(item), entering: false),
  ];

  @override
  void didUpdateWidget(covariant DitherList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final current = {for (final item in widget.items) widget.keyOf(item): item};
    final shown = {for (final entry in _entries) entry.key: entry};
    final entries = [
      for (final item in widget.items)
        shown[widget.keyOf(item)]?.update(item) ??
            _Entry(item, widget.keyOf(item), entering: true),
    ];
    for (final (index, entry) in _entries.indexed) {
      if (current.containsKey(entry.key)) continue;
      entries.insert(index.clamp(0, entries.length), entry.leave());
    }
    _entries = entries;
  }

  void _left(Object key) {
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.key == key && e.leaving));
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: widget.padding,
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return _Presence(
          key: ValueKey(entry.key),
          entering: entry.entering,
          leaving: entry.leaving,
          onLeft: () => _left(entry.key),
          child: widget.itemBuilder(context, entry.item),
        );
      },
    );
  }
}

class _Entry<T> {
  _Entry(this.item, this.key, {required this.entering, this.leaving = false});

  final T item;
  final Object key;
  final bool entering;
  final bool leaving;

  _Entry<T> update(T item) => _Entry(item, key, entering: entering && !leaving);

  _Entry<T> leave() => _Entry(item, key, entering: false, leaving: true);
}

/// One row: the first half of its run opens or closes its height, the
/// second develops or dissolves it.
class _Presence extends StatefulWidget {
  const _Presence({
    required this.entering,
    required this.leaving,
    required this.onLeft,
    required this.child,
    super.key,
  });

  final bool entering;
  final bool leaving;
  final VoidCallback onLeft;
  final Widget child;

  @override
  State<_Presence> createState() => _PresenceState();
}

class _PresenceState extends State<_Presence>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: DitherTransition.duration * 2,
    value: widget.entering ? 0 : 1,
  );

  bool _animate = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (!_started && widget.entering) _run(forward: true);
    _started = true;
  }

  @override
  void didUpdateWidget(covariant _Presence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.leaving != oldWidget.leaving) _run(forward: !widget.leaving);
  }

  void _run({required bool forward}) {
    // Without motion the row is simply there, or gone the next frame.
    final animate = _animate;
    if (forward) {
      animate ? _controller.forward() : _controller.value = 1;
      return;
    }
    if (!animate) {
      _controller.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onLeft());
      return;
    }
    _controller.reverse().whenCompleteOrCancel(() {
      if (_controller.isDismissed) widget.onLeft();
    });
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
        final progress = _controller.value;
        if (progress >= 1) return child!;
        final opened = Curves.easeInOut.transform(
          (progress * 2).clamp(0.0, 1.0),
        );
        final developed = (progress * 2 - 1).clamp(0.0, 1.0);
        return IgnorePointer(
          ignoring: widget.leaving,
          child: ClipRect(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              heightFactor: opened,
              child: BayerMasked(
                open: (developed * BayerMask.steps).round(),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
