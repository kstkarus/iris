import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/bootstrap/episode_sync_lifecycle.dart';
import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/episode_sync_repository.dart';
import 'package:iris/entities/user_rate/domain/episode_watch_sync.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';

import '../features/auth/presentation/auth_test_doubles.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets(
    'restored account, resume, and later sign-in drain durable work',
    (tester) async {
      final rates = MockUserRateRepository();
      final sync = EpisodeWatchSync(
        storage: _MemoryQueue(),
        rates: rates,
        sessionGeneration: () => 0,
      );
      final auth = AuthCubit(
        repository: FakeAuthRepository(restored: testAccount),
      );
      await auth.restore();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        testApp(
          BlocProvider.value(
            value: auth,
            child: EpisodeSyncLifecycle(sync: sync, child: const Scaffold()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(rates.rates['1']?.episodes, 2);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await sync(userId: '42', animeId: '1', episode: 3);
      expect(rates.rates['1']?.episodes, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(rates.rates['1']?.episodes, 3);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await sync(userId: '42', animeId: '1', episode: 4);
      await auth.signOut();
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(rates.rates['1']?.episodes, 3);
      await auth.signIn();
      await tester.pumpAndSettle();
      expect(rates.rates['1']?.episodes, 4);
      expect(sync.state.pending, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      var closed = false;
      sync.close().then((_) => auth.close()).then((_) => closed = true);
      // Let cancellation callbacks cross the widget test's clock boundary.
      for (var step = 0; step < 6 && !closed; step++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(closed, isTrue);
    },
  );
}

class _MemoryQueue implements EpisodeSyncRepository {
  @override
  List<EpisodeSyncEntry> read() => [
    const EpisodeSyncEntry(userId: '42', animeId: '1', episodes: [2]),
  ];

  @override
  Future<void> write(List<EpisodeSyncEntry> entries) async {}
}
