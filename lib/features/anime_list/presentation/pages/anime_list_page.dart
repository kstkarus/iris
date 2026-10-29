import 'package:flutter/material.dart';

import 'package:iris/features/anime_details/domain/repositories/anime_details_repository.dart';
import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

/// The catalog. The search field heads the page: the section's name is
/// already in the navigation.
class AnimeListPage extends StatelessWidget {
  const AnimeListPage({this.detailsRepository, super.key});

  final AnimeDetailsRepository? detailsRepository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageFrame(
          child: AnimeListView(detailsRepository: detailsRepository),
        ),
      ),
    );
  }
}
