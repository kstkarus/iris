import 'package:dio/dio.dart';

import 'package:iris/entities/user_rate/data/user_rate_dto.dart';
import 'package:iris/entities/user_rate/domain/user_rate.dart';
import 'package:iris/entities/user_rate/domain/user_rate_repository.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_graph_ql_client.dart';

/// Reads the entry through GraphQL (`Anime.userRate`) and writes it through
/// REST: Shikimori's GraphQL API has no mutations.
///
/// Both go through the Shikimori Dio, which signs them in.
class RemoteUserRateRepository implements UserRateRepository {
  const RemoteUserRateRepository({
    required ShikimoriGraphQlClient graphQl,
    required Dio dio,
  }) : _graphQl = graphQl,
       _dio = dio;

  static const _ratesPath = '/api/v2/user_rates';

  final ShikimoriGraphQlClient _graphQl;
  final Dio _dio;

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
    return anime is Map
        ? UserRateDto.tryParse(anime['userRate'])?.toEntity()
        : null;
  }

  @override
  Future<UserRate> save({
    required String userId,
    required String animeId,
    required String? rateId,
    required UserRateStatus status,
    required int episodes,
  }) async {
    final fields = {
      'status': UserRateDto.statusToApi(status),
      'episodes': episodes,
    };
    final Response<dynamic> response;
    try {
      response = rateId == null
          ? await _dio.post<dynamic>(
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
          : await _dio.patch<dynamic>(
              '$_ratesPath/$rateId',
              data: {'user_rate': fields},
            );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
    final saved = UserRateDto.tryParse(response.data);
    if (saved == null) {
      throw const RemoteResponseException('User rate response is invalid.');
    }
    return saved.toEntity();
  }

  @override
  Future<void> remove(String rateId) async {
    try {
      await _dio.delete<dynamic>('$_ratesPath/$rateId');
    } on DioException catch (error) {
      throw mapDioException(error);
    }
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
    }
  }
}
''';
