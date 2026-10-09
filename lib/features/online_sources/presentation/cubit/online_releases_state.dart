import 'package:iris/features/online_sources/domain/entities/online_release.dart';

sealed class OnlineReleasesState {
  const OnlineReleasesState();
}

final class OnlineReleasesLoading extends OnlineReleasesState {
  const OnlineReleasesLoading();

  @override
  bool operator ==(Object other) => other is OnlineReleasesLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class OnlineReleasesLoaded extends OnlineReleasesState {
  const OnlineReleasesLoaded(this.releases);

  /// Never empty: no release is [OnlineReleasesEmpty].
  final List<OnlineRelease> releases;

  @override
  bool operator ==(Object other) {
    if (other is! OnlineReleasesLoaded) return false;
    if (other.releases.length != releases.length) return false;
    for (var index = 0; index < releases.length; index++) {
      if (other.releases[index] != releases[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(releases);
}

final class OnlineReleasesEmpty extends OnlineReleasesState {
  const OnlineReleasesEmpty();

  @override
  bool operator ==(Object other) => other is OnlineReleasesEmpty;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class OnlineReleasesFailure extends OnlineReleasesState {
  const OnlineReleasesFailure();

  @override
  bool operator ==(Object other) => other is OnlineReleasesFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
