import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/features/anime_details/presentation/cubit/friend_rates_cubit.dart';
import 'package:iris/features/anime_details/presentation/widgets/friends_section.dart';
import 'package:iris/l10n/generated/app_localizations.dart';

import '../../../../entities/friend/friend_test_doubles.dart';

void main() {
  Future<FriendRatesCubit> pumpSection(
    WidgetTester tester,
    FakeFriendsRepository repository,
  ) async {
    final cubit = FriendRatesCubit(animeId: '10', repository: repository);
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider.value(
            value: cubit,
            child: const FriendsSection(totalEpisodes: 12),
          ),
        ),
      ),
    );
    return cubit;
  }

  testWidgets('shows the friends who have the anime', (tester) async {
    final cubit = await pumpSection(
      tester,
      FakeFriendsRepository(
        list: [testFriend('1'), testFriend('2')],
        rates: {
          '2': const UserRate(
            id: 'a',
            status: UserRateStatus.watching,
            episodes: 5,
            score: 7,
          ),
        },
      ),
    );
    expect(find.text('FRIENDS'), findsNothing);

    await tester.runAsync(() => cubit.show('42'));
    await tester.pump();

    expect(find.text('FRIENDS'), findsOneWidget);
    expect(find.text('friend_2'), findsOneWidget);
    expect(find.text('WATCHING · 5/12 · SCORE: 7'), findsOneWidget);
    expect(find.text('friend_1'), findsNothing);
  });

  testWidgets('no friend with the anime, no section', (tester) async {
    final cubit = await pumpSection(
      tester,
      FakeFriendsRepository(list: [testFriend('1')]),
    );

    await tester.runAsync(() => cubit.show('42'));
    await tester.pump();

    expect(find.text('FRIENDS'), findsNothing);
  });
}
