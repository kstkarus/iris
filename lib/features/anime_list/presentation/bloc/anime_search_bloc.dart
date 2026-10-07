import 'package:iris/features/anime_list/presentation/bloc/anime_list_bloc.dart';

/// Search results over the catalog: the same paging, sort and filters as
/// [AnimeListBloc], kept apart so the catalog stays as it was while
/// searching. Without a query there is no search and nothing is fetched.
class AnimeSearchBloc extends AnimeListBloc {
  AnimeSearchBloc({required super.repository});

  @override
  bool get fetchesWithoutQuery => false;
}
