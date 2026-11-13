import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';
import 'package:iris/features/profile/domain/entities/user_list_entry.dart';
import 'package:iris/features/profile/presentation/cubit/friends_cubit.dart';
import 'package:iris/features/profile/presentation/cubit/user_list_cubit.dart';
import 'package:iris/features/profile/presentation/widgets/user_list_view.dart';
import 'package:iris/shared/widgets/adaptive/page_frame.dart';
import 'package:iris/shared/widgets/status_views.dart';

import '../../../entities/friend/friend_test_doubles.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_window.dart';
import 'user_list_test_doubles.dart';

void main() {
  for (final mine in [false, true]) {
    testWidgets(
      'loads a full wide viewport for ${mine ? 'own' : 'friend'} list',
      (tester) async {
        setTestWindowSize(tester, TestWindowSizes.desktop);
        final repository = _repository(31, pageSize: 30);
        final cubit = UserListCubit(repository: repository)..show('user');
        addTearDown(cubit.close);

        await tester.pumpWidget(_page(cubit, mine: mine));
        await tester.pumpAndSettle();

        expect(repository.requests.map((request) => request.page), [1, 2]);
        expect(cubit.state.entries.length, 31);
        expect(cubit.state.hasMore, isFalse);
        expect(find.text('Anime 31'), findsOneWidget);
      },
    );
  }

  testWidgets('a wider window fetches the next page without scrolling', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 600));
    final repository = _repository(31, pageSize: 30);
    final cubit = UserListCubit(repository: repository)..show('user');
    addTearDown(cubit.close);

    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1]);

    tester.view.physicalSize = TestWindowSizes.desktop;
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    expect(cubit.state.entries.length, 31);
  });

  testWidgets('scrolling still fetches more and keeps its position', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 600));
    final repository = _repository(31, pageSize: 30);
    final cubit = UserListCubit(repository: repository)..show('user');
    addTearDown(cubit.close);

    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);

    final position = tester.state<ScrollableState>(find.byType(Scrollable));
    final offset = position.position.pixels;
    expect(offset, greaterThan(0));
    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();
    expect(position.position.pixels, offset);
  });

  testWidgets('checks again after each page and stops at the end', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final repository = _repository(7, pageSize: 2);
    final cubit = UserListCubit(repository: repository)..show('user');
    addTearDown(cubit.close);

    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();

    expect(repository.requests.map((request) => request.page), [1, 2, 3, 4]);
    expect(cubit.state.hasMore, isFalse);
    expect(cubit.state.entries.length, 7);
  });

  testWidgets('a failed page waits for a manual retry', (tester) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final repository = _FailSecondPageRepository(31, pageSize: 30);
    final cubit = UserListCubit(repository: repository)..show('user');
    addTearDown(cubit.close);

    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);
    expect(find.byType(InlineRetry), findsOneWidget);

    tester.view.physicalSize = const Size(1600, 1000);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(InlineRetry));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);

    repository.failSecondPage = false;
    await tester.tap(find.widgetWithText(TextButton, 'Try Again'));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2, 2]);
    expect(cubit.state.entries.length, 31);
    expect(find.byType(InlineRetry), findsNothing);
  });

  testWidgets('a failed quiet refresh does not strand a pending prefetch', (
    tester,
  ) async {
    setTestWindowSize(tester, const Size(400, 600));
    final repository = _repository(31, pageSize: 30);
    final changes = StreamController<UserRateChange>.broadcast();
    final cubit = UserListCubit(repository: repository, changes: changes.stream)
      ..show('user');
    addTearDown(cubit.close);
    addTearDown(changes.close);

    await tester.pumpWidget(_page(cubit));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1]);

    final quietRead = Completer<void>();
    repository.gate = quietRead;
    repository.lists[UserRateStatus.watching]!.insert(0, listEntry('32'));
    changes.add(
      const UserRateChange(
        '32',
        UserRate(id: 'r32', status: UserRateStatus.watching, episodes: 3),
      ),
    );
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 1]);

    tester.view.physicalSize = TestWindowSizes.desktop;
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 1]);

    repository.gate = null;
    repository.failure = Exception('offline');
    quietRead.completeError(Exception('offline'));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 1, 2]);
    expect(find.byType(InlineRetry), findsOneWidget);

    repository.failure = null;
    await tester.tap(find.widgetWithText(TextButton, 'Try Again'));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 1, 2, 2]);
    expect(find.text('Anime 31'), findsOneWidget);
  });

  testWidgets('does not prefetch while hidden and resumes when shown', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final repository = _repository(31, pageSize: 30);
    final cubit = UserListCubit(repository: repository)..show('user');
    final visible = ValueNotifier(false);
    addTearDown(cubit.close);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_page(cubit, visible: visible));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1]);

    visible.value = true;
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);
  });

  testWidgets('does not prefetch on Friends and resumes on List', (
    tester,
  ) async {
    setTestWindowSize(tester, TestWindowSizes.desktop);
    final gate = Completer<void>();
    final repository = _repository(31, pageSize: 30)..gate = gate;
    final cubit = UserListCubit(repository: repository)..show('user');
    final friends = FriendsCubit(repository: FakeFriendsRepository())
      ..show('user');
    addTearDown(cubit.close);
    addTearDown(friends.close);

    await tester.pumpWidget(_page(cubit, friends: friends));
    await tester.pump();
    await tester.tap(find.byKey(UserListView.friendsTabKey));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1]);

    await tester.tap(find.byKey(UserListView.listTabKey));
    await tester.pumpAndSettle();
    expect(repository.requests.map((request) => request.page), [1, 2]);
  });

  for (final fail in [false, true]) {
    testWidgets('filtered empty page ${fail ? 'can retry' : 'loads more'}', (
      tester,
    ) async {
      setTestWindowSize(tester, TestWindowSizes.desktop);
      final repository = _FailSecondPageRepository(3, pageSize: 2)
        ..failSecondPage = fail;
      final rates = MockUserRateRepository();
      final book = UserRateBookCubit(repository: rates);
      await rates.remove(animeId: '1', rateId: 'r1');
      await rates.remove(animeId: '2', rateId: 'r2');
      await tester.pump();
      final cubit = UserListCubit(repository: repository)..show('user');
      addTearDown(cubit.close);
      addTearDown(book.close);

      await tester.pumpWidget(_page(cubit, mine: true, book: book));
      await tester.pumpAndSettle();
      expect(repository.requests.map((request) => request.page), [1, 2]);
      expect(find.text('Nothing in “Watching”'), findsNothing);

      if (fail) {
        expect(find.byType(InlineRetry), findsOneWidget);
        repository.failSecondPage = false;
        await tester.tap(find.widgetWithText(TextButton, 'Try Again'));
        await tester.pumpAndSettle();
        expect(repository.requests.map((request) => request.page), [1, 2, 2]);
      }
      expect(find.text('Anime 3'), findsOneWidget);
      expect(cubit.state.hasMore, isFalse);
    });
  }
}

FakeUserListRepository _repository(int count, {required int pageSize}) =>
    FakeUserListRepository({
      UserRateStatus.watching: [
        for (var i = 1; i <= count; i++) listEntry('$i'),
      ],
    }, pageSize: pageSize);

class _FailSecondPageRepository extends FakeUserListRepository {
  _FailSecondPageRepository(int count, {required super.pageSize})
    : super({
        UserRateStatus.watching: [
          for (var i = 1; i <= count; i++) listEntry('$i'),
        ],
      });

  bool failSecondPage = true;

  @override
  Future<UserListPage> page({
    required String userId,
    required UserRateStatus status,
    required int page,
  }) {
    if (page == 2 && failSecondPage) {
      requests.add((userId: userId, status: status, page: page));
      throw Exception('offline');
    }
    return super.page(userId: userId, status: status, page: page);
  }
}

Widget _page(
  UserListCubit cubit, {
  bool mine = false,
  UserRateBookCubit? book,
  FriendsCubit? friends,
  ValueNotifier<bool>? visible,
}) {
  final view = Scaffold(
    body: PageFrame(
      child: UserListView(
        header: const SizedBox(height: 160),
        onOpen: (_) {},
        onOpenFriend: friends == null ? null : (_) {},
        mine: mine,
      ),
    ),
  );
  return testApp(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: cubit),
        if (book != null) BlocProvider.value(value: book),
        if (friends != null) BlocProvider.value(value: friends),
      ],
      child: visible == null
          ? view
          : ValueListenableBuilder(
              valueListenable: visible,
              builder: (context, enabled, _) =>
                  TickerMode(enabled: enabled, child: view),
            ),
    ),
  );
}
