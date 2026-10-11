import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/widgets/account_listener.dart';

import 'auth_test_doubles.dart';

void main() {
  testWidgets('reports each change of the account, not of the state', (
    tester,
  ) async {
    final repository = FakeAuthRepository();
    final cubit = AuthCubit(repository: repository);
    addTearDown(cubit.close);
    final changes = <String?>[];

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: AccountListener(
          onChanged: (_, accountId) => changes.add(accountId),
          child: const SizedBox(),
        ),
      ),
    );

    // Restoring to signed out keeps the account unchanged: none.
    await cubit.restore();
    await tester.pump();
    expect(changes, isEmpty);

    await cubit.signIn();
    await tester.pump();
    expect(changes, [testAccount.id]);

    await cubit.signOut();
    await tester.pump();
    expect(changes, [testAccount.id, null]);
  });
}
