import 'package:iris/features/anime_details/domain/entities/anime_details.dart';

sealed class AnimeDetailsState {
  const AnimeDetailsState();
}

final class AnimeDetailsInitial extends AnimeDetailsState {
  const AnimeDetailsInitial();

  @override
  bool operator ==(Object other) => other is AnimeDetailsInitial;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimeDetailsLoading extends AnimeDetailsState {
  const AnimeDetailsLoading();

  @override
  bool operator ==(Object other) => other is AnimeDetailsLoading;

  @override
  int get hashCode => runtimeType.hashCode;
}

final class AnimeDetailsSuccess extends AnimeDetailsState {
  const AnimeDetailsSuccess(this.details);

  final AnimeDetails details;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is AnimeDetailsSuccess && other.details == details;
  }

  @override
  int get hashCode => details.hashCode;
}

final class AnimeDetailsFailure extends AnimeDetailsState {
  const AnimeDetailsFailure();

  @override
  bool operator ==(Object other) => other is AnimeDetailsFailure;

  @override
  int get hashCode => runtimeType.hashCode;
}
