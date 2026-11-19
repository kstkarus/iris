import 'package:flutter/material.dart';

import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/utils/motion_duration.dart';
import 'package:iris/shared/widgets/active_layer.dart';
import 'package:iris/shared/widgets/detail_layout.dart';
import 'package:iris/shared/widgets/segmented_bar.dart';

/// Retry card when full details fail to load on top of a preview.
class DetailRetryBanner extends StatelessWidget {
  const DetailRetryBanner({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: DetailLayout.cardDecoration(theme.colorScheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: InlineRetry(
          message: message,
          onRetry: onRetry,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontFamily: DetailLayout.sansFont,
          ),
        ),
      ),
    );
  }
}

/// A centred loading state: a short run of blocks sweeping across a bar and
/// what is being waited for.
class LoadingView extends StatelessWidget {
  const LoadingView({
    this.label,
    this.semanticsLabel,
    this.details = const [],
    super.key,
  });

  final String? label;

  /// What a screen reader announces when there is no visible [label].
  final String? semanticsLabel;

  /// Secondary lines under the label, such as a percentage and a speed.
  final List<String> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = this.label;
    final semanticsLabel = label == null ? this.semanticsLabel : null;
    final view = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 160, child: BlockSpinner()),
            if (label != null) ...[
              const SizedBox(height: 16),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                ),
              ),
            ],
            for (final line in details) ...[
              const SizedBox(height: 4),
              MixedDataText(
                line,
                textAlign: TextAlign.center,
                sansStyle: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: DetailLayout.sansFont,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                monoStyle: DetailLayout.monoTelemetryStyle(
                  theme.textTheme.bodySmall,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
    if (semanticsLabel == null) return view;
    return Semantics(label: semanticsLabel, child: view);
  }
}

/// An indeterminate block bar.
class BlockSpinner extends StatefulWidget {
  const BlockSpinner({this.height = 8, super.key});

  final double height;

  @override
  State<BlockSpinner> createState() => _BlockSpinnerState();
}

class _BlockSpinnerState extends State<BlockSpinner>
    with SingleTickerProviderStateMixin {
  static const _blocks = 12;
  static const _run = 3;

  /// The frame held without motion: a run of lit blocks mid-bar.
  static const _stillValue = 0.5;

  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.isAnimating
              ? _controller.value
              : _stillValue;
          final head = (value * (_blocks + _run)).floor();
          return SizedBox(
            height: widget.height,
            // Stretched: an empty ColoredBox is otherwise zero high.
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var index = 0; index < _blocks; index++) ...[
                  if (index > 0) const SizedBox(width: 2),
                  Expanded(
                    child: ColoredBox(
                      color: index < head && index >= head - _run
                          ? scheme.onSurface
                          : scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A centred message for empty and failed states, with an optional icon and action.
class MessageView extends StatelessWidget {
  const MessageView({
    required this.message,
    this.title,
    this.icon,
    this.action,
    super.key,
  });

  final String? title;
  final String message;
  final Widget? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = this.title;
    final icon = this.icon;
    final action = this.action;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon, const SizedBox(height: 24)],
              if (title != null) ...[
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    wordSpacing: -3.6,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style:
                    (title == null
                            ? theme.textTheme.bodyLarge
                            : theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ))
                        ?.copyWith(
                          fontFamily: DetailLayout.sansFont,
                          height: 1.4,
                        ),
              ),
              if (action != null) ...[const SizedBox(height: 24), action],
            ],
          ),
        ),
      ),
    );
  }
}

/// A [MessageView] for a failed load, with a button that tries again.
class RetryView extends StatelessWidget {
  const RetryView({required this.message, required this.onRetry, super.key});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MessageView(
      message: message,
      action: FilledButton(
        onPressed: onRetry,
        child: Text(AppLocalizations.of(context).commonRetry),
      ),
    );
  }
}

/// A failure in the flow of a page: the message, then a way to try again.
class InlineRetry extends StatelessWidget {
  const InlineRetry({
    required this.message,
    required this.onRetry,
    this.style,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(message, style: style)),
        const SizedBox(width: 12),
        TextButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).commonRetry),
        ),
      ],
    );
  }
}

enum _PagingFooterSlot { loading, failed, idle }

/// The end of a paged list: a spinner while the next page loads, or why
/// it did not, with a way to try again; [idle] otherwise.
class PagingFooter extends StatelessWidget {
  const PagingFooter({
    required this.loadingMore,
    required this.failed,
    required this.failedMessage,
    required this.onRetry,
    this.topSpacing = 0,
    this.idle = const SizedBox.shrink(),
    super.key,
  });

  final bool loadingMore;
  final bool failed;
  final String failedMessage;
  final VoidCallback onRetry;
  final double topSpacing;
  final Widget idle;

  @override
  Widget build(BuildContext context) {
    final anim = motionDuration(context, const Duration(milliseconds: 180));
    final Widget content;
    if (loadingMore) {
      content = Padding(
        key: const ValueKey(_PagingFooterSlot.loading),
        padding: EdgeInsets.only(top: topSpacing + 8, bottom: 8),
        child: const Center(child: SizedBox(width: 120, child: BlockSpinner())),
      );
    } else if (failed) {
      content = Column(
        key: const ValueKey(_PagingFooterSlot.failed),
        children: [
          if (topSpacing > 0) SizedBox(height: topSpacing),
          const SegmentedRule(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: InlineRetry(message: failedMessage, onRetry: onRetry),
          ),
        ],
      );
    } else {
      content = KeyedSubtree(
        key: const ValueKey(_PagingFooterSlot.idle),
        child: idle,
      );
    }
    if (anim == Duration.zero) return content;
    return AnimatedSize(
      duration: anim,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: anim,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeOutCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: ActiveLayer.switcherChildren(
            currentChild,
            previousChildren,
          ),
        ),
        child: content,
      ),
    );
  }
}
