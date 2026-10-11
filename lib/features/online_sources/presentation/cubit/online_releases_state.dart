import 'package:iris/features/online_sources/domain/entities/online_release.dart';
import 'package:iris/shared/utils/equality.dart';

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
  const OnlineReleasesLoaded(this.releases, {this.searching = false});

  /// Never empty: no release is [OnlineReleasesEmpty].
  final List<OnlineRelease> releases;

  /// A server has not answered yet: more may come.
  final bool searching;

  @override
  bool operator ==(Object other) =>
      other is OnlineReleasesLoaded &&
      other.searching == searching &&
      sameList(other.releases, releases);

  @override
  int get hashCode => Object.hash(searching, Object.hashAll(releases));
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
