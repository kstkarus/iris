import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:iris/shared/utils/bayer_mask.dart';
import 'package:iris/shared/utils/ordered_dither.dart';
import 'package:iris/shared/widgets/pixel_noise.dart';

/// [image] redrawn as a colour halftone: square dots from a small palette,
/// with in-between tones mixed by ordered dithering. About [dotsAcross]
/// dots span the box's width at any size, so a small cover on a phone
/// keeps as much of the picture as a large one on a desktop.
///
/// The halftone develops out of the empty panel when the image arrives,
/// and a tap swaps it for the picture itself and back. Both changes run
/// cell by cell in the order of the same Bayer screen, so the picture
/// develops instead of fading in.
///
/// The picture covers its box like [BoxFit.cover]; give it bounded
/// constraints (an [AspectRatio] or a sized box). Until the image arrives
/// the box is [PixelNoise]; if it fails, an empty panel. A new [image]
/// takes the old one's place without developing again.
class DitheredImage extends StatefulWidget {
  const DitheredImage({
    required this.image,
    this.dotsAcross = 106,
    this.levels = 5,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.showOriginalLabel,
    this.showHalftoneLabel,
    super.key,
  });

  final ImageProvider image;

  /// Dots across the box, about: each dot is a whole number of device
  /// pixels, and never less than [minDotPixels].
  final int dotsAcross;

  /// Steps per colour channel.
  final int levels;
  final Alignment alignment;
  final String? semanticLabel;

  /// Tooltips for the tap that swaps the two views; without them the
  /// image does not react to taps.
  final String? showOriginalLabel;
  final String? showHalftoneLabel;

  /// The smallest dot, in device pixels; finer would read as the picture.
  static const minDotPixels = 2;

  /// The side of one dot, in logical pixels, for a box [width] wide.
  @visibleForTesting
  static double dotSize({
    required double width,
    required double devicePixelRatio,
    required int dotsAcross,
  }) {
    final pixels = (width * devicePixelRatio / dotsAcross).round();
    return math.max(pixels, minDotPixels) / devicePixelRatio;
  }

  static const revealDuration = Duration(milliseconds: 520);
  static const appearDuration = Duration(milliseconds: 360);

  @override
  State<DitheredImage> createState() => _DitheredImageState();
}

class _DitheredImageState extends State<DitheredImage>
    with TickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: DitheredImage.revealDuration,
  );
  late final AnimationController _appear = AnimationController(
    vsync: this,
    duration: DitheredImage.appearDuration,
  )..addStatusListener(_onAppearStatus);
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _reveal,
    curve: Curves.easeInOut,
  );
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(
    _onImage,
    onError: _onError,
  );

  ui.Image? _photo;
  _Source? _source;
  _Halftone? _halftone;
  (_Source, _Grid)? _pending;
  bool _failed = false;

  bool get _interactive =>
      widget.showOriginalLabel != null && widget.showHalftoneLabel != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(DitheredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  /// Bumped by every image that arrives: a slow read of an older one does
  /// not replace a newer one read sooner.
  int _imageRead = 0;

  Future<void> _onImage(ImageInfo info, bool synchronousCall) async {
    final read = ++_imageRead;
    final image = info.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (!mounted || data == null || read != _imageRead) {
      info.dispose();
      return;
    }
    setState(() {
      _photo?.dispose();
      _photo = image.clone();
      _source = _Source(data.buffer.asUint8List(), image.width, image.height);
      _failed = false;
    });
    info.dispose();
  }

  void _onError(Object error, StackTrace? stackTrace) {
    if (mounted && _source == null) setState(() => _failed = true);
  }

  // Once the halftone covers the box, the noise under it can go.
  void _onAppearStatus(AnimationStatus status) {
    if (status.isCompleted && mounted) setState(() {});
  }

  /// Builds the halftone of the current image for [grid] unless it is
  /// already shown or on its way; a newer request wins over an older one
  /// still in flight.
  void _ensureHalftone(_Grid grid) {
    final source = _source;
    if (source == null) return;
    final shown = _halftone;
    if (shown != null && shown.source == source && shown.grid == grid) return;
    if (_pending == (source, grid)) return;
    _pending = (source, grid);
    final rgb = coverSample(
      source.pixels,
      sourceWidth: source.width,
      sourceHeight: source.height,
      width: grid.width,
      height: grid.height,
      alignX: widget.alignment.x,
      alignY: widget.alignment.y,
    );
    final pixels = orderedDither(rgb, width: grid.width, levels: widget.levels);
    ui.decodeImageFromPixels(
      pixels,
      grid.width,
      grid.height,
      ui.PixelFormat.rgba8888,
      (image) {
        if (!mounted || _pending != (source, grid)) {
          image.dispose();
          return;
        }
        setState(() {
          final first = _halftone == null;
          _halftone?.image.dispose();
          _halftone = _Halftone(image, grid, source);
          _pending = null;
          if (first) {
            if (MediaQuery.disableAnimationsOf(context)) {
              _appear.value = 1;
            } else {
              _appear.forward();
            }
          }
        });
      },
    );
  }

  void _toggle() {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final showOriginal = _reveal.value < 0.5;
    if (!animate) {
      _reveal.value = showOriginal ? 1 : 0;
    } else if (showOriginal) {
      _reveal.forward();
    } else {
      _reveal.reverse();
    }
  }

  @override
  void dispose() {
    _curve.dispose();
    _reveal.dispose();
    _appear.dispose();
    _stream?.removeListener(_listener);
    _halftone?.image.dispose();
    _photo?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final image = LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        if (size.isEmpty || !size.isFinite) return const SizedBox.shrink();
        final cell = DitheredImage.dotSize(
          width: size.width,
          devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
          dotsAcross: widget.dotsAcross,
        );
        final grid = _Grid(
          (size.width / cell).ceil(),
          (size.height / cell).ceil(),
        );
        if (_source != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ensureHalftone(grid);
          });
        }
        final halftone = _halftone;
        final photo = _photo;
        final settled = halftone != null && _appear.isCompleted;
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_failed)
                ColoredBox(color: scheme.surfaceContainer)
              // Cells not developed yet keep showing the noise.
              else if (!settled)
                const PixelNoise(),
              if (halftone != null && photo != null)
                CustomPaint(
                  size: size,
                  painter: _RevealPainter(
                    halftone: halftone,
                    photo: photo,
                    cell: cell,
                    alignment: widget.alignment,
                    appear: _appear,
                    reveal: _curve,
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (!_interactive) {
      return Semantics(
        label: widget.semanticLabel,
        image: widget.semanticLabel != null,
        child: image,
      );
    }
    return AnimatedBuilder(
      animation: _reveal,
      builder: (context, child) {
        final label = _reveal.value < 0.5
            ? widget.showOriginalLabel!
            : widget.showHalftoneLabel!;
        return Tooltip(
          message: label,
          child: Semantics(
            label: widget.semanticLabel,
            image: true,
            button: true,
            onTapHint: label,
            child: child,
          ),
        );
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: _toggle, child: image),
      ),
    );
  }
}

/// Paints the halftone in the cells [appear] has opened and the picture
/// itself in those [reveal] has, both in Bayer order.
class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.halftone,
    required this.photo,
    required this.cell,
    required this.alignment,
    required this.appear,
    required this.reveal,
  }) : super(repaint: Listenable.merge([appear, reveal]));

  final _Halftone halftone;
  final ui.Image photo;
  final double cell;
  final Alignment alignment;
  final Animation<double> appear;
  final Animation<double> reveal;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shown = (appear.value * BayerMask.steps).ceil();
    final revealed = (reveal.value * BayerMask.steps).floor();
    if (revealed < BayerMask.steps) {
      _masked(canvas, bounds, shown, _paintHalftone);
    }
    _masked(canvas, bounds, revealed, (canvas) => _paintPhoto(canvas, bounds));
  }

  void _masked(
    Canvas canvas,
    Rect bounds,
    int open,
    void Function(Canvas canvas) paint,
  ) {
    if (open <= 0) return;
    if (open >= BayerMask.steps) {
      paint(canvas);
      return;
    }
    canvas.saveLayer(bounds, Paint());
    paint(canvas);
    canvas
      ..drawRect(
        bounds,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = BayerMask.shader(open, cell: cell),
      )
      ..restore();
  }

  void _paintHalftone(Canvas canvas) {
    final grid = halftone.grid;
    canvas.drawImageRect(
      halftone.image,
      Rect.fromLTWH(0, 0, grid.width.toDouble(), grid.height.toDouble()),
      Rect.fromLTWH(0, 0, grid.width * cell, grid.height * cell),
      Paint()..filterQuality = FilterQuality.none,
    );
  }

  void _paintPhoto(Canvas canvas, Rect bounds) {
    paintImage(
      canvas: canvas,
      rect: bounds,
      image: photo,
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_RevealPainter old) =>
      old.halftone != halftone ||
      old.photo != photo ||
      old.cell != cell ||
      old.alignment != alignment;
}

/// A built halftone and what it was built from.
class _Halftone {
  const _Halftone(this.image, this.grid, this.source);

  final ui.Image image;
  final _Grid grid;
  final _Source source;
}

class _Source {
  const _Source(this.pixels, this.width, this.height);

  final Uint8List pixels;
  final int width;
  final int height;
}

class _Grid {
  const _Grid(this.width, this.height);

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is _Grid && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}
