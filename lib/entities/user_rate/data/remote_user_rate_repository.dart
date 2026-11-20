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
  }) : this._(
         graphQl,
         rest,
         session,
         StreamController<UserRateChange>.broadcast(),
         SerialQueue(),
         {},
         null,
       );

  RemoteUserRateRepository._(
    this._graphQl,
    this._rest,
    this._session,
    this._changes,
    this._requests,
    this._statuses,
    this._editGeneration,
  );

  static const _ratesPath = '/api/v2/user_rates';

  final ShikimoriGraphQlClient _graphQl;
  final ShikimoriRestClient _rest;
  final ShikimoriSessionStore _session;
  final StreamController<UserRateChange> _changes;
  final SerialQueue _requests;
  final Map<String, UserRateStatus> _statuses;
  final int? _editGeneration;
  int? _statusesGeneration;

  @override
  Stream<UserRateChange> get changes => _changes.stream;

  @override
  Future<T> editRate<T>(Future<T> Function(UserRateRepository) edit) => _run(
    (generation) => edit(
      RemoteUserRateRepository._(
        _graphQl,
        _rest,
        _session,
        _changes,
        _requests,
        _statuses,
        generation,
      ),
    ),
  );

  Future<T> _run<T>(Future<T> Function(int generation) request) {
    // Calls inside editRate already hold the queue and use its session.
    if (_editGeneration case final generation?) return request(generation);
    final generation = _session.generation;
    return _requests.run(() {
      if (_statusesGeneration != generation) {
        _statuses.clear();
        _statusesGeneration = generation;
      }
      return request(generation);
    });
  }

  @override
  Future<UserRate?> fetch(String animeId) async =>
      (await fetchWithTotal(animeId)).rate;

  @override
  Future<({UserRate? rate, int totalEpisodes})> fetchWithTotal(
    String animeId,
  ) => _run((requestGeneration) async {
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
    await _publishIfCurrent(sessionGeneration, animeId, rate);
    return (rate: rate, totalEpisodes: jsonInt(anime['episodes']));
  });

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    UserRateStatus? status,
    int? episodes,
    int? score,
    int? rewatches,
  }) => _run((requestGeneration) async {
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
    await _publishIfCurrent(sessionGeneration, animeId, rate, mutation: true);
    return rate;
  });

  @override
  Future<void> remove({required String animeId, required String rateId}) =>
      _run((requestGeneration) async {
        final sessionGeneration = await _sessionGeneration(requestGeneration);
        await _rest.delete(
          '$_ratesPath/$rateId',
          sessionGeneration: requestGeneration,
        );
        await _publishIfCurrent(
          sessionGeneration,
          animeId,
          null,
          mutation: true,
        );
      });

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
    String animeId,
    UserRate? rate, {
    bool mutation = false,
  }) async {
    if (sessionGeneration >= 0 &&
        await _session.read() != null &&
        _session.generation == sessionGeneration) {
      final previousStatus = _statuses[animeId];
      if (rate == null) {
        _statuses.remove(animeId);
      } else {
        _statuses[animeId] = rate.status;
      }
      _changes.add(
        mutation
            ? UserRateMutation(animeId, rate, previousStatus: previousStatus)
            : UserRateChange(animeId, rate),
      );
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
