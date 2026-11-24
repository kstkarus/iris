import 'package:dio/dio.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/tenrai_api.dart';

class TenraiApiClient {
  const TenraiApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// Fetches one page of episodes for [malId]; returns null on HTTP 404.
  Future<Map<String, dynamic>?> fetchEpisodesPage({
    required String malId,
    int page = 1,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        TenraiApi.episodesPath(malId),
        queryParameters: {'page': page},
      );
      if (response.statusCode == 404) return null;
      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Unexpected Tenrai episodes response payload.',
        );
      }
      return payload;
    } on DioException catch (error) {
      throw NetworkRequestException(error.message ?? 'Unable to reach Tenrai.');
    }
  }
}
