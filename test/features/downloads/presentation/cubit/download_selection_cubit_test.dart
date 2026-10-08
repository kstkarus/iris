import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/downloads/data/repositories/mock_downloads_repository.dart';
import 'package:iris/features/downloads/domain/entities/prepared_download_source.dart';
import 'package:iris/features/downloads/presentation/cubit/download_selection_cubit.dart';
import 'package:iris/features/downloads/presentation/models/download_selection_args.dart';

const _args = DownloadSelectionArgs(
  animeId: '154587',
  animeTitle: 'Sousou no Frieren',
  sourceTitle: 'Release',
  magnet: 'magnet:?xt=urn:btih:test-selection',
);

void main() {
  test('closing during a preparation cancels it', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var isCancelled = false;
    unawaited(repository.cancellations.single!.then((_) => isCancelled = true));

    await cubit.close();
    await Future<void>.delayed(Duration.zero);

    expect(isCancelled, isTrue);
  });

  test('loading again cancels the preparation it replaces', () async {
    final repository = _DeferredPrepareRepository();
    final cubit = DownloadSelectionCubit(args: _args, repository: repository);

    unawaited(cubit.load());
    var firstCancelled = false;
    unawaited(
      repository.cancellations.single!.then((_) => firstCancelled = true),
    );

    unawaited(cubit.load());
    await Future<void>.delayed(Duration.zero);

    expect(firstCancelled, isTrue);
    expect(repository.cancellations, hasLength(2));
    await cubit.close();
  });
}

class _DeferredPrepareRepository extends MockDownloadsRepository {
  final List<Future<void>?> cancellations = [];

  @override
  Future<PreparedDownloadSource> prepareSource({
    required String magnet,
    Future<void>? cancelled,
  }) {
    cancellations.add(cancelled);
    return Completer<PreparedDownloadSource>().future;
  }
}
