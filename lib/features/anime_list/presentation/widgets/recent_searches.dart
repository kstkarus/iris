import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/anime_list/presentation/cubit/search_history_cubit.dart';
import 'package:iris/l10n/generated/app_localizations.dart';
import 'package:iris/shared/widgets/adaptive/adaptive_content_width.dart';
import 'package:iris/shared/widgets/dither_list.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/status_views.dart';

class RecentSearches extends StatelessWidget {
  const RecentSearches({required this.onSelected, super.key});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SearchHistoryCubit?>();
    final queries = history?.state ?? const <String>[];
    final l10n = AppLocalizations.of(context);
    return Stack(
      key: const Key('catalog_recent_searches'),
      fit: StackFit.expand,
      children: [
        if (queries.isEmpty)
          MessageView(
            message: l10n.searchRecentEmpty,
            icon: PixelIcon(
              PixelGlyph.search,
              size: 42,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        IgnorePointer(
          ignoring: queries.isEmpty,
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AdaptiveContentWidth.form,
              ),
              child: DitherList<String>(
                items: queries,
                keyOf: (query) => query,
                header: SizedBox(
                  height: 44,
                  child: queries.isEmpty
                      ? null
                      : Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: history!.clear,
                            child: Text(l10n.searchRecentClear),
                          ),
                        ),
                ),
                itemBuilder: (context, query) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const PixelIcon(PixelGlyph.search, size: 16),
                  title: Text(query),
                  onTap: () => onSelected(query),
                  trailing: IconButton(
                    tooltip: l10n.searchRecentRemove(query),
                    onPressed: () => history!.remove(query),
                    icon: const PixelIcon(PixelGlyph.close, size: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
