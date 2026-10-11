import 'package:flutter/material.dart';

import 'package:iris/features/anime_list/presentation/widgets/anime_list_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';

/// The catalog. The search field heads the page: the section's name is
/// already in the navigation.
class AnimeListPage extends StatelessWidget {
  const AnimeListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(child: PageFrame(child: AnimeListView())),
    );
  }
}
