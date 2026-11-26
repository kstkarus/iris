import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/app/theme/app_theme.dart';
import 'package:iris/entities/friend/domain/friend.dart';
import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/auth/domain/entities/auth_failure.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_cubit.dart';
import 'package:iris/features/profile/presentation/pages/profile_page.dart';
import 'package:iris/features/profile/presentation/pages/user_profile_page.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/shared/widgets/adaptive/window_size_class.dart';
import 'package:iris/shared/widgets/page_title.dart';
import 'package:iris/shared/widgets/pixel_icon.dart';
import 'package:iris/shared/widgets/status_views.dart';

import '../../../entities/friend/friend_test_doubles.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';
import '../../auth/presentation/auth_test_doubles.dart';
import 'user_list_test_doubles.dart';

void main() {
  late FakeUserListRepository lists;
  late MockUserRateRepository rates;
  late List<UserListEntry> opened;
  late FakeFriendsRepository friends;
  late List<Friend> openedFriends;
  late int catalogOpens;

  setUp(() {
    lists = FakeUserListRepository({
      UserRateStatus.watching: [
        listEntry('1', episodes: 5, score: 8),
        listEntry('2'),
      ],
      UserRateStatus.planned: [listEntry('3', status: UserRateStatus.planned)],
    });
    rates = MockUserRateRepository();
    opened = [];
    friends = FakeFriendsRepository(list: [testFriend('7')]);
    openedFriends = [];
    catalogOpens = 0;
  });

  Future<AuthCubit> pumpPage(
    WidgetTester tester,
    FakeAuthRepository repository, {
    Locale locale = const Locale('en'),
    VoidCallback? onOpenSettings,
    ThemeData? theme,
  }) async {
    final cubit = AuthCubit(repository: repository);
    if (repository.restoreGate == null) {
      await cubit.restore();
    } else {
      unawaited(cubit.restore());
    }
    final userList = UserListCubit(repository: lists)
      ..show(accountIdOf(cubit.state));
    final book = UserRateBookCubit(repository: rates);
    final friendsCubit = FriendsCubit(repository: friends)
      ..show(accountIdOf(cubit.state));
    addTearDown(() async {
      await cubit.close();
      await userList.close();
      await book.close();
      await friendsCubit.close();
    });
    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: userList),
            BlocProvider.value(value: book),
            BlocProvider.value(value: friendsCubit),
          ],
          child: BlocListener<AuthCubit, AuthState>(
            listener: (context, auth) => userList.show(accountIdOf(auth)),
            child: ProfilePage(
              onOpenAnime: opened.add,
              onOpenFriend: openedFriends.add,
              onBrowseCatalog: () => catalogOpens++,
              onOpenSettings: onOpenSettings ?? () {},
            ),
          ),
        ),
        locale: locale,
        theme: theme,
      ),
    );
    await tester.pump();
    return cubit;
  }

  FilledButton signInButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.byKey(ProfilePage.signInButtonKey));

  testWidgets('signed out, it invites to sign in', (tester) async {
    final repository = FakeAuthRepository()..signInGate = Completer();
    await pumpPage(tester, repository);

    expect(find.text('Shikimori account'), findsOneWidget);
    expect(signInButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(ProfilePage.signInButtonKey));
    await tester.pump();
    expect(find.text('Waiting for Shikimori'), findsOneWidget);

    repository.signInGate!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('kstk'), findsOneWidget);
  });

  testWidgets('without sign-in set up, the button is off and says why', (
    tester,
  ) async {
    await pumpPage(tester, FakeAuthRepository(canSignIn: false));

    expect(find.text('Sign-in is not set up in this build'), findsOneWidget);
    expect(signInButton(tester).onPressed, isNull);
  });

  testWidgets('a failed sign-in says so in place of the invitation', (
    tester,
  ) async {
    final repository = FakeAuthRepository()
      ..failure = const AuthNetworkFailure();
    await pumpPage(tester, repository);

    await tester.tap(find.byKey(ProfilePage.signInButtonKey));
    await tester.pump();
    await tester.pump();

    expect(find.text('No response from Shikimori.'), findsOneWidget);
  });

  testWidgets('a session Shikimori ended asks to sign in again', (
    tester,
  ) async {
    final repository = FakeAuthRepository(restored: testAccount);
    await pumpPage(tester, repository);

    repository.expire();
    await tester.pump();
    await tester.pump();

    expect(find.text('Session expired. Sign in again.'), findsOneWidget);
  });

  testWidgets('a narrow profile lists the anime by status', (tester) async {
    setTestWindowSize(tester, const Size(320, 800));
    await pumpPage(
      tester,
      FakeAuthRepository(restored: testAccount),
      locale: const Locale('ru'),
    );
    await tester.pumpAndSettle();

    expect(lists.requests.single.userId, testAccount.id);
    expect(find.text('Anime 1'), findsOneWidget);
    expect(
      find.textContaining('5 из 12 сер.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('8'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Оценка: 8')), findsOneWidget);
    expect(find.text('Anime 3'), findsNothing);

    final statusButton = tester.getSemantics(
      find.byKey(UserListView.statusButtonKey),
    );
    expect(statusButton.flagsCollection.isButton, isTrue);
    await chooseStatus(tester, 'planned');
    expect(find.text('Anime 1'), findsNothing);
    expect(find.text('Anime 3'), findsOneWidget);

    await tester.tap(find.text('Anime 3'));
    expect(opened.single.anime.id, '3');
  });

  testWidgets('a change made elsewhere shows at once', (tester) async {
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();

    await rates.save(
      userId: testAccount.id,
      animeId: '1',
      rateId: 'r1',
      status: UserRateStatus.watching,
      episodes: 6,
      score: 9,
    );
    await rates.save(
      userId: testAccount.id,
      animeId: '2',
      rateId: 'r2',
      status: UserRateStatus.completed,
      episodes: 12,
      score: 0,
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('6 of 12 ep.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('9'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Score: 9')), findsOneWidget);
    expect(find.text('Anime 2'), findsNothing);
  });

  testWidgets('an empty status says so', (tester) async {
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();

    await chooseStatus(tester, 'dropped');

    expect(find.text('Nothing in “Dropped”'), findsOneWidget);
    expect(find.text('Set a status from an anime’s page.'), findsOneWidget);
  });

  testWidgets('the previous category fades out before the new list appears', (
    tester,
  ) async {
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();

    final response = Completer<void>();
    lists.gate = response;
    await tester.tap(find.byKey(UserListView.statusButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('user_list_status_planned')));
    await tester.pump();
    await tester.pump();

    double opacity() => tester
        .widget<SliverFadeTransition>(find.byType(SliverFadeTransition))
        .opacity
        .value;
    final beforeFade = opacity();
    await tester.pump(const Duration(milliseconds: 32));
    expect(opacity(), lessThan(beforeFade));
    expect(find.text('Anime 1'), findsOneWidget);
    expect(find.text('Anime 1').hitTestable(), findsNothing);

    response.complete();
    await tester.pumpAndSettle();
    expect(find.text('Anime 1'), findsNothing);
    expect(find.text('Anime 3').hitTestable(), findsOneWidget);
  });

  testWidgets('an empty Watching list leads to the catalog', (tester) async {
    lists.lists.remove(UserRateStatus.watching);
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(UserListView.browseCatalogKey));
    expect(catalogOpens, 1);
  });

  testWidgets('a list that did not load can be tried again', (tester) async {
    lists.failure = Exception('offline');
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load list.'), findsOneWidget);

    lists.failure = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Anime 1'), findsOneWidget);
  });

  testWidgets('friends are read when their tab is opened', (tester) async {
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();
    expect(friends.friendReads, 0);

    await tester.tap(find.byKey(UserListView.friendsTabKey));
    await tester.pumpAndSettle();

    expect(find.text('Anime 1'), findsNothing);
    await tester.tap(find.text('friend_7'));
    expect(openedFriends.single.id, '7');

    await tester.tap(find.byKey(UserListView.listTabKey));
    await tester.pumpAndSettle();
    expect(find.text('Anime 1'), findsOneWidget);
  });

  testWidgets('switching profile tabs shows the first row of the new section', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    lists = FakeUserListRepository({
      UserRateStatus.watching: [for (var i = 1; i <= 24; i++) listEntry('$i')],
    });
    friends.list = [for (var i = 1; i <= 30; i++) testFriend('$i')];
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    position.jumpTo(1600);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UserListView.friendsTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('friend_1').hitTestable());
    expect(openedFriends.single.id, '1');

    position.jumpTo(900);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UserListView.listTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anime 1').hitTestable());
    expect(opened.single.anime.id, '1');
  });

  testWidgets('friends that did not load can be tried again', (tester) async {
    friends.friendsFailure = Exception('offline');
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(UserListView.friendsTabKey));
    await tester.pumpAndSettle();
    expect(find.text('Couldn’t load friends.'), findsOneWidget);

    friends.friendsFailure = null;
    await tester.tap(find.widgetWithText(FilledButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('friend_7'), findsOneWidget);
  });

  testWidgets('friend page shows the name in the bar after scrolling', (
    tester,
  ) async {
    final longLists = FakeUserListRepository({
      UserRateStatus.watching: [
        for (var i = 1; i <= 20; i++) listEntry('$i', episodes: 5, score: 8),
      ],
    });
    final userList = UserListCubit(repository: longLists)..show('7');
    final book = UserRateBookCubit(repository: rates);
    addTearDown(() async {
      await userList.close();
      await book.close();
    });

    await tester.pumpWidget(
      testApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: userList),
            BlocProvider.value(value: book),
          ],
          child: Navigator(
            pages: [
              const MaterialPage<void>(child: SizedBox.shrink()),
              MaterialPage<void>(
                child: UserProfilePage(
                  friend: testFriend('7'),
                  onOpenAnime: opened.add,
                ),
              ),
            ],
            onDidRemovePage: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    expect(find.byType(PageTitle), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.byType(PageTitle), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PageTitle),
        matching: find.text('friend_7'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'List <-> Friends and rate removals transition cleanly and honor reduced motion',
    (tester) async {
      await pumpPage(tester, FakeAuthRepository(restored: testAccount));
      await tester.pumpAndSettle();

      expect(find.byKey(UserListView.statusButtonKey), findsOneWidget);
      await tester.tap(find.byKey(UserListView.friendsTabKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 90));
      final statusMenu = find.byKey(UserListView.statusButtonKey);
      expect(statusMenu, findsOneWidget);
      expect(statusMenu.hitTestable(), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byKey(UserListView.statusButtonKey), findsNothing);
      expect(find.text('friend_7'), findsOneWidget);

      await tester.tap(find.byKey(UserListView.listTabKey));
      await tester.pumpAndSettle();
      expect(find.byKey(UserListView.statusButtonKey), findsOneWidget);
      expect(find.text('Anime 1'), findsOneWidget);

      // Removing the remaining items collapses them before showing empty state.
      await rates.save(
        userId: testAccount.id,
        animeId: '1',
        rateId: 'r1',
        status: UserRateStatus.completed,
        episodes: 12,
        score: 0,
      );
      await rates.save(
        userId: testAccount.id,
        animeId: '2',
        rateId: 'r2',
        status: UserRateStatus.completed,
        episodes: 12,
        score: 0,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 32));
      await tester.pump(const Duration(milliseconds: 64));
      await tester.pump();
      expect(find.text('Anime 1'), findsOneWidget);
      expect(find.text('Nothing in “Watching”'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.text('Anime 1'), findsNothing);
      expect(find.text('Nothing in “Watching”'), findsOneWidget);

      // With reduced motion, tab and status menu switches complete at once.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pump();
      await tester.tap(find.byKey(UserListView.friendsTabKey));
      await tester.pump();
      expect(find.byKey(UserListView.statusButtonKey), findsNothing);
      final sliverFade = tester.widget<SliverFadeTransition>(
        find.byType(SliverFadeTransition),
      );
      expect(sliverFade.opacity.value, 1.0);
    },
  );

  testWidgets('compact Settings stays put through restoring and sign-in', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.phone);
    var settingsOpens = 0;
    final restore = Completer<void>();
    final signIn = Completer<void>();
    final repository = FakeAuthRepository()
      ..restoreGate = restore
      ..signInGate = signIn;

    final cubit = await pumpPage(
      tester,
      repository,
      onOpenSettings: () => settingsOpens++,
      theme: buildAppTheme(brightness: Brightness.dark),
    );
    final gear = find.byKey(ProfilePage.settingsButtonKey);
    final glyph = find.descendant(of: gear, matching: find.byType(PixelIcon));
    expect(cubit.state, isA<AuthRestoring>());
    final placement = tester.getRect(gear);
    final glyphPlacement = tester.getRect(glyph);
    expect(
      placement.right,
      TestWindowSizes.phone.width - WindowSizeClass.compact.pageMargin,
    );
    expect(glyphPlacement.right, closeTo(placement.right, 2));
    expect(placement.width, greaterThanOrEqualTo(48));

    restore.complete();
    await tester.pumpAndSettle();
    expect(tester.getRect(gear), placement);
    expect(tester.getRect(glyph), glyphPlacement);
    expect(
      tester.getCenter(find.byType(MessageView)).dy,
      (TestWindowSizes.phone.height + WindowSizeClass.compact.pageTop) / 2,
    );
    await tester.tap(gear);
    expect(settingsOpens, 1);

    await tester.tap(find.byKey(ProfilePage.signInButtonKey));
    await tester.pump();
    expect(cubit.state, isA<AuthSigningIn>());
    expect(tester.getRect(gear), placement);
    expect(tester.getRect(glyph), glyphPlacement);

    signIn.complete();
    await tester.pumpAndSettle();
    expect(tester.getRect(gear), placement);
    expect(tester.getRect(glyph), glyphPlacement);
    expect(tester.getCenter(find.text('kstk')).dy, placement.center.dy);
    await tester.tap(gear);
    expect(settingsOpens, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop profile hides compact Settings button', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    await pumpPage(tester, FakeAuthRepository(restored: testAccount));
    await tester.pumpAndSettle();

    expect(find.byKey(ProfilePage.settingsButtonKey), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> chooseStatus(WidgetTester tester, String status) async {
  await tester.tap(find.byKey(UserListView.statusButtonKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('user_list_status_$status')));
  await tester.pumpAndSettle();
}
