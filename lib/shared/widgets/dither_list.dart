import 'package:flutter/material.dart';

import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_grid_row.dart';
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
    this.header,
    this.footer,
    this.physics,
    this.crossAxisCount = 1,
    this.columnSpacing = 16,
    this.rowSpacing = 0,
    super.key,
  }) : assert(crossAxisCount > 0);

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final EdgeInsetsGeometry? padding;

  /// Static content that scrolls together with the animated rows.
  final Widget? header;
  final Widget? footer;
  final ScrollPhysics? physics;

  /// Groups entries into rows while keeping presence transitions per entry.
  final int crossAxisCount;
  final double columnSpacing;
  final double rowSpacing;

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
    final headerCount = widget.header == null ? 0 : 1;
    final rowCount = (_entries.length / widget.crossAxisCount).ceil();
    return ListView.builder(
      padding: widget.padding,
      physics: widget.physics,
      itemCount: headerCount + rowCount + (widget.footer == null ? 0 : 1),
      // A row keeps its state when rows come or go above it, rather than
      // being matched by place and built anew, opening again.
      findChildIndexCallback: (key) {
        if (key is! ValueKey<Object>) return null;
        if (key.value == _StaticPart.header) {
          return widget.header == null ? null : 0;
        }
        if (key.value == _StaticPart.footer) {
          return widget.footer == null ? null : headerCount + rowCount;
        }
        final index = _entries.indexWhere((entry) => entry.key == key.value);
        return index < 0 || index % widget.crossAxisCount != 0
            ? null
            : headerCount + index ~/ widget.crossAxisCount;
      },
      itemBuilder: (context, index) {
        if (index < headerCount) {
          return KeyedSubtree(
            key: const ValueKey(_StaticPart.header),
            child: widget.header!,
          );
        }
        final rowIndex = index - headerCount;
        if (rowIndex == rowCount) {
          return KeyedSubtree(
            key: const ValueKey(_StaticPart.footer),
            child: widget.footer!,
          );
        }
        final start = rowIndex * widget.crossAxisCount;
        final end = (start + widget.crossAxisCount).clamp(0, _entries.length);
        final rowEntries = _entries.sublist(start, end);
        return KeyedSubtree(
          key: ValueKey<Object>(rowEntries.first.key),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: rowIndex + 1 < rowCount ? widget.rowSpacing : 0,
            ),
            child: AdaptiveGridRow(
              columns: widget.crossAxisCount,
              spacing: widget.columnSpacing,
              children: [
                for (final entry in rowEntries)
                  _Presence(
                    key: ValueKey<Object>(entry.key),
                    entering: entry.entering,
                    leaving: entry.leaving,
                    onEntered: () => entry.entering = false,
                    onLeft: () => _left(entry.key),
                    child: widget.itemBuilder(context, entry.item),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _StaticPart { header, footer }

class _Entry<T> {
  _Entry(this.item, this.key, {required this.entering, this.leaving = false});

  final T item;
  final Object key;

  /// Until the row has started opening: built again later (scrolled back
  /// to), it is simply there.
  bool entering;
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
    required this.onEntered,
    required this.onLeft,
    required this.child,
    super.key,
  });

  final bool entering;
  final bool leaving;
  final VoidCallback onEntered;
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
  bool _gone = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animate = !MediaQuery.disableAnimationsOf(context);
    if (!_started && widget.entering) {
      widget.onEntered();
      _run(forward: true);
    }
    // Built while leaving (scrolled back to after it was removed): there
    // is no dissolve to watch, so it is simply gone.
    if (!_started && widget.leaving) _leaveNextFrame();
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
      _leaveNextFrame();
      return;
    }
    _controller.reverse().whenCompleteOrCancel(() {
      if (_controller.isDismissed) _leave();
    });
  }

  void _leaveNextFrame() {
    final onLeft = widget.onLeft;
    WidgetsBinding.instance.addPostFrameCallback((_) => _leave(onLeft));
  }

  void _leave([VoidCallback? onLeft]) {
    if (_gone) return;
    _gone = true;
    (onLeft ?? widget.onLeft)();
  }

  @override
  void dispose() {
    // Scrolled away mid-dissolve: the row would come back whole later.
    if (widget.leaving && !_gone) _leaveNextFrame();
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
