import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:iris/entities/user_rate/domain/episode_watch_sync.dart';
import 'package:iris/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:iris/features/auth/presentation/cubit/auth_state.dart';
import 'package:iris/features/auth/presentation/widgets/account_listener.dart';

/// Keeps synchronization alive outside the player, only for the active account.
class EpisodeSyncLifecycle extends StatefulWidget {
  const EpisodeSyncLifecycle({
    required this.sync,
    required this.child,
    super.key,
  });

  final EpisodeWatchSync sync;
  final Widget child;

  @override
  State<EpisodeSyncLifecycle> createState() => _EpisodeSyncLifecycleState();
}

class _EpisodeSyncLifecycleState extends State<EpisodeSyncLifecycle> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    final state = WidgetsBinding.instance.lifecycleState;
    widget.sync.setForeground(
      state == null || state == AppLifecycleState.resumed,
    );
    widget.sync.accountChanged(accountIdOf(context.read<AuthCubit>().state));
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) =>
          widget.sync.setForeground(state == AppLifecycleState.resumed),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    widget.sync.setForeground(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccountListener(
    onChanged: (_, accountId) => widget.sync.accountChanged(accountId),
    child: widget.child,
  );
}
