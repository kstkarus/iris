import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';

/// Calls [onChanged] with the new account id whenever the signed-in account
/// changes: a sign-in, a sign-out or another account.
class AccountListener extends StatelessWidget {
  const AccountListener({
    super.key,
    required this.onChanged,
    required this.child,
  });

  final void Function(BuildContext context, String? accountId) onChanged;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          accountIdOf(previous) != accountIdOf(current),
      listener: (context, auth) => onChanged(context, accountIdOf(auth)),
      child: child,
    );
  }
}
