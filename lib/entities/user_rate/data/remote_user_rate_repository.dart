import 'dart:async';

import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';
import 'package:iris/shared/network/shikimori_rest_client.dart';
import 'package:iris/shared/storage/shikimori_session_store.dart';
import 'package:iris/shared/utils/json_read.dart';
import 'package:iris/shared/utils/serial_queue.dart';

/// Reads the entry through GraphQL (`Anime.userRate`) and writes it through
/// REST: Shikimori's GraphQL API has no mutations.
///
/// Both go through the Shikimori Dio, which signs them in.
class RemoteUserRateRepository implements UserRateRepository {
  RemoteUserRateRepository({
    required ShikimoriGraphQlClient graphQl,
    required ShikimoriRestClient rest,
    required ShikimoriSessionStore session,
  }) : _graphQl = graphQl,
       _rest = rest,
       _session = session;

  static const _ratesPath = '/api/v2/user_rates';

  final ShikimoriGraphQlClient _graphQl;
  final ShikimoriRestClient _rest;
  final ShikimoriSessionStore _session;
  final _changes = StreamController<UserRateChange>.broadcast();
  final _requests = SerialQueue();

  @override
  Stream<UserRateChange> get changes => _changes.stream;

  @override
  Future<UserRate?> fetch(String animeId) async =>
      (await fetchWithTotal(animeId)).rate;

  @override
  Future<({UserRate? rate, int totalEpisodes})> fetchWithTotal(String animeId) {
    final requestGeneration = _session.generation;
    return _requests.run(() async {
      final sessionGeneration = await _sessionGeneration(requestGeneration);
      final data = await _graphQl.query(
        document: _userRateQuery,
        variables: {'id': animeId},
      );
      final animes = data['animes'];
      if (animes is! List || animes.isEmpty) {
        throw ResourceNotFoundException('Anime not found for id: $animeId');
      }
      final anime = jsonMap(animes.first);
      final rate = UserRateDto.tryParse(anime['userRate'])?.toEntity();
      await _publishIfCurrent(sessionGeneration, UserRateChange(animeId, rate));
      return (rate: rate, totalEpisodes: jsonInt(anime['episodes']));
    });
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    int? episodes,
    int? score,
    int? rewatches,
  }) {
    final requestGeneration = _session.generation;
    return _requests.run(() async {
      final sessionGeneration = await _sessionGeneration(requestGeneration);
      final fields = {
        if (status != null) 'status': UserRateDto.statusToApi(status),
        'episodes': ?episodes,
        'score': ?score,
        'rewatches': ?rewatches,
      };
      final data = rateId == null
          ? await _rest.post(
              _ratesPath,
              sessionGeneration: requestGeneration,
              data: {
                'user_rate': {
                  'user_id': userId,
                  'target_id': animeId,
                  'target_type': 'Anime',
                  ...fields,
                },
              },
            )
          : await _rest.patch(
              '$_ratesPath/$rateId',
              data: {'user_rate': fields},
              sessionGeneration: requestGeneration,
            );
      final saved = UserRateDto.tryParse(data);
      if (saved == null) {
        throw const RemoteResponseException('User rate response is invalid.');
      }
      final rate = saved.toEntity();
      await _publishIfCurrent(sessionGeneration, UserRateChange(animeId, rate));
      return rate;
    });
  }

  @override
  Future<void> remove({required String animeId, required String rateId}) {
    final requestGeneration = _session.generation;
    return _requests.run(() async {
      final sessionGeneration = await _sessionGeneration(requestGeneration);
      await _rest.delete(
        '$_ratesPath/$rateId',
        sessionGeneration: requestGeneration,
      );
      await _publishIfCurrent(sessionGeneration, UserRateChange(animeId, null));
    });
  }

  /// A queued request must not start under a different account.
  Future<int> _sessionGeneration(int generation) async {
    final tokens = await _session.read();
    if (_session.generation != generation) {
      throw const NetworkRequestException('The request was cancelled.');
    }
    return tokens == null ? -1 : generation;
  }

  /// An in-flight request may return after its account has changed.
  Future<void> _publishIfCurrent(
    int sessionGeneration,
    UserRateChange change,
  ) async {
    if (sessionGeneration >= 0 &&
        await _session.read() != null &&
        _session.generation == sessionGeneration) {
      _changes.add(change);
    }
  }
}

const _userRateQuery = r'''
query UserRate($id: String!) {
  animes(ids: $id, limit: 1, censored: false) {
    id
    episodes
    userRate {
      id
      status
      episodes
      score
      rewatches
    }
  }
}
''';
