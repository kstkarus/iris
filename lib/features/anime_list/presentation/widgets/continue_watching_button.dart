import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:iris/entities/watch_progress/domain/watch_progress.dart';
import 'package:iris/entities/watch_progress/presentation/watch_progress_cubit.dart';
import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';
import 'package:iris/features/anime_list/presentation/cubit/continue_watching_posters_cubit.dart';
import 'package:iris/features/anime_list/presentation/widgets/continue_watching_row.dart';
import 'package:iris/features/player/presentation/models/anime_player_source_args.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/show_adaptive_sheet.dart';
import 'package:iris/shared/theme/inverse_theme.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/checked_menu_item.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/search_field.dart';

class ContinueWatchingButton extends StatefulWidget {
  const ContinueWatchingButton({this.repository, super.key});

  static const buttonKey = Key('continue_watching_button');
  final AnimeDetailsRepository? repository;

  @override
  State<ContinueWatchingButton> createState() => _ContinueWatchingButtonState();
}

class _ContinueWatchingButtonState extends State<ContinueWatchingButton> {
  final _menu = MenuController();
  ContinueWatchingPostersCubit? _posters;

  @override
  void initState() {
    super.initState();
    _createPosters();
  }

  void _createPosters() {
    final repository = widget.repository;
    _posters = repository == null
        ? null
        : ContinueWatchingPostersCubit(repository: repository);
  }

  @override
  void didUpdateWidget(ContinueWatchingButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _posters?.close();
      _createPosters();
    }
  }

  @override
  void dispose() {
    _posters?.close();
    super.dispose();
  }

  void _loadPosters() {
    final items = continueWatchingItems(
      context.read<WatchProgressCubit>().state,
    );
    final known = {
      for (final item in context.read<AnimeListBloc>().state.items)
        if (item.anime.posterUrl.isNotEmpty)
          item.anime.id: item.anime.posterUrl,
    };
    final posters = _posters;
    if (posters != null) unawaited(posters.load(items, known));
  }

  Widget _contents(VoidCallback close) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<WatchProgressCubit>()),
        if (_posters case final posters?) BlocProvider.value(value: posters),
      ],
      child: _HistoryContents(
        onEmpty: close,
        onOpen: (progress) {
          close();
          context.pushNamed(
            'torrent-stream-files',
            extra: AnimePlayerSourceArgs.resume(progress),
          );
        },
        onOpenAnime: (progress) {
          close();
          context.pushNamed(
            'anime-details',
            pathParameters: {'id': progress.animeId},
          );
        },
      ),
    );
  }

  void _showSheet() {
    _loadPosters();
    final navigator = Navigator.of(context, rootNavigator: true);
    showAdaptiveSheet<void>(
      context: context,
      builder: (_) =>
          SafeArea(top: false, child: _contents(() => navigator.pop())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = WindowSizeClass.of(context).isCompact;
    final label = AppLocalizations.of(context).continueWatchingTitle;
    const icon = PixelIcon(PixelGlyph.play, size: 18);
    Widget button(VoidCallback onPressed) => compact
        ? IconButton.filledTonal(
            key: ContinueWatchingButton.buttonKey,
            tooltip: label,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              minimumSize: const Size.square(SearchField.height),
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHigh,
            ),
            icon: icon,
          )
        : OutlinedButton.icon(
            key: ContinueWatchingButton.buttonKey,
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, SearchField.height),
            ),
            icon: icon,
            label: Text(label),
          );
    if (compact) return button(_showSheet);
    final inverse = InverseTheme.of(Theme.of(context));
    const width = 360.0;
    return MenuAnchor(
      controller: _menu,
      onOpen: _loadPosters,
      alignmentOffset: const Offset(-width, SearchField.height + 8),
      crossAxisUnconstrained: false,
      style: MenuStyle(
        alignment: AlignmentDirectional.topEnd,
        backgroundColor: WidgetStatePropertyAll(
          inverse.colorScheme.surfaceContainerLow,
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(width, 0)),
        maximumSize: const WidgetStatePropertyAll(Size(width, double.infinity)),
      ),
      menuChildren: [
        Theme(
          data: inverse,
          child: Focus(autofocus: true, child: _contents(_menu.close)),
        ),
      ],
      builder: (_, controller, _) => button(controller.toggle),
    );
  }
}

class _HistoryContents extends StatelessWidget {
  const _HistoryContents({
    required this.onOpen,
    required this.onOpenAnime,
    required this.onEmpty,
  });

  final ValueChanged<WatchProgress> onOpen;
  final ValueChanged<WatchProgress> onOpenAnime;
  final VoidCallback onEmpty;

  @override
  Widget build(BuildContext context) {
    return BlocListener<WatchProgressCubit, List<WatchProgress>>(
      listener: (_, history) {
        if (continueWatchingItems(history).isEmpty) onEmpty();
      },
      child: Builder(
        builder: (context) {
          final items = continueWatchingItems(context.watchWatchProgress());
          final posters =
              context.watch<ContinueWatchingPostersCubit?>()?.state ??
              const <String, String>{};
          return SingleChildScrollView(
            primary: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ContinueWatchingRow(
                items: items,
                posters: posters,
                onOpen: onOpen,
                onOpenAnime: onOpenAnime,
                onRemove: (progress) => context
                    .read<WatchProgressCubit>()
                    .removeTorrent(progress.torrentKey),
              ),
            ),
          );
        },
      ),
    );
  }
}
