import 'package:iris/entities/user_rate/domain/user_rate.dart';

sealed class UserRateState {
  const UserRateState();
}

/// No account: there is no list to show.
final class UserRateSignedOut extends UserRateState {
  const UserRateSignedOut();

  @override
  bool operator ==(Object other) => other is UserRateSignedOut;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class UserRateLoading extends UserRateState {
  const UserRateLoading();

  @override
  bool operator ==(Object other) => other is UserRateLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class UserRateLoadFailure extends UserRateState {
  const UserRateLoadFailure();

  @override
  bool operator ==(Object other) => other is UserRateLoadFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class UserRateLoaded extends UserRateState {
  const UserRateLoaded(
    this.rate, {
    this.saving = false,
    this.saveFailed = false,
  });

  /// Null when the anime is not in the list. While [saving], what the user
  /// asked for, ahead of Shikimori.
  final UserRate? rate;

  final bool saving;

  /// The last change did not reach Shikimori; [rate] is what it keeps.
  final bool saveFailed;

  @override
  bool operator ==(Object other) =>
      other is UserRateLoaded &&
      other.rate == rate &&
      other.saving == saving &&
      other.saveFailed == saveFailed;

  @override
  int get hashCode => Object.hash(rate, saving, saveFailed);
}
