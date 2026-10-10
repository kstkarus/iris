import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/entities/user_rate/data/mock_user_rate_repository.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/presentation/user_rate_book_cubit.dart';

void main() {
  const fromList = UserRate(
    id: '9',
    status: UserRateStatus.planned,
    episodes: 0,
  );

  late MockUserRateRepository repository;
  late UserRateBookCubit book;

  setUp(() {
    repository = MockUserRateRepository();
    book = UserRateBookCubit(repository: repository);
  });

  tearDown(() => book.close());

  Future<void> save(UserRateStatus status) => repository.save(
    userId: '42',
    animeId: '1',
    rateId: null,
    status: status,
    episodes: 2,
    score: 0,
  );

  test('keeps the latest entry seen per anime, removals too', () async {
    await save(UserRateStatus.watching);
    await pumpEventQueue();
    expect(book.state['1']?.status, UserRateStatus.watching);

    await repository.remove(animeId: '1', rateId: '1');
    await pumpEventQueue();
    expect(book.state.containsKey('1'), isTrue);
    expect(book.state['1'], isNull);

    book.clear();
    expect(book.state, isEmpty);
  });

  testWidgets('a screen shows the book over its own data', (tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: book,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) {
              final rate = context.watchUserRate('1', fromList);
              return Text(rate?.status.name ?? 'none');
            },
          ),
        ),
      ),
    );
    expect(find.text('planned'), findsOneWidget);

    await tester.runAsync(() => save(UserRateStatus.completed));
    await tester.pump();
    expect(find.text('completed'), findsOneWidget);

    await tester.runAsync(() => repository.remove(animeId: '1', rateId: '1'));
    await tester.pump();
    expect(find.text('none'), findsOneWidget);
  });

  testWidgets('without a book the screen keeps its own data', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) =>
              Text(context.watchUserRate('1', fromList)?.status.name ?? ''),
        ),
      ),
    );

    expect(find.text('planned'), findsOneWidget);
  });
}
