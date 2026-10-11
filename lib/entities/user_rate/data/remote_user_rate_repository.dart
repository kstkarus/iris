import 'dart:async';

import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';

/// Reads the entry through GraphQL (`Anime.userRate`) and writes it through
/// REST: Shikimori's GraphQL API has no mutations.
///
/// Both go through the Shikimori Dio, which signs them in.
class RemoteUserRateRepository implements UserRateRepository {
  RemoteUserRateRepository({
    required ShikimoriGraphQlClient graphQl,
    required ShikimoriRestClient rest,
  }) : _graphQl = graphQl,
       _rest = rest;

  static const _ratesPath = '/api/v2/user_rates';

  final ShikimoriGraphQlClient _graphQl;
  final ShikimoriRestClient _rest;
  final _changes = StreamController<UserRateChange>.broadcast();

  @override
  Stream<UserRateChange> get changes => _changes.stream;

  @override
  Future<UserRate?> fetch(String animeId) async {
    final data = await _graphQl.query(
      document: _userRateQuery,
      variables: {'id': animeId},
    );
    final animes = data['animes'];
    if (animes is! List || animes.isEmpty) {
      throw ResourceNotFoundException('Anime not found for id: $animeId');
    }
    final anime = animes.first;
    final rate = anime is Map
        ? UserRateDto.tryParse(anime['userRate'])?.toEntity()
        : null;
    _changes.add(UserRateChange(animeId, rate));
    return rate;
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
    required int score,
  }) async {
    final fields = {
      'status': UserRateDto.statusToApi(status),
      'episodes': episodes,
      'score': score,
    };
    final data = rateId == null
        ? await _rest.post(
            _ratesPath,
            data: {
              'user_rate': {
                'user_id': userId,
                'target_id': animeId,
                'target_type': 'Anime',
                ...fields,
              },
            },
          )
        : await _rest.patch('$_ratesPath/$rateId', data: {'user_rate': fields});
    final saved = UserRateDto.tryParse(data);
    if (saved == null) {
      throw const RemoteResponseException('User rate response is invalid.');
    }
    final rate = saved.toEntity();
    _changes.add(UserRateChange(animeId, rate));
    return rate;
  }

  @override
  Future<void> remove({required String animeId, required String rateId}) async {
    await _rest.delete('$_ratesPath/$rateId');
    _changes.add(UserRateChange(animeId, null));
  }
}

const _userRateQuery = r'''
query UserRate($id: String!) {
  animes(ids: $id, limit: 1, censored: false) {
    id
    userRate {
      id
      status
      episodes
      score
    }
  }
}
''';
