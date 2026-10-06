import 'package:dio/dio.dart';

import 'package:iris/shared/network/aniskip_api.dart';
import 'package:iris/shared/network/network_exceptions.dart';

class AniSkipApiClient {
  const AniSkipApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// [episodeLength] in seconds; AniSkip matches it against the length of
  /// the release its times were taken from.
  Future<Map<String, dynamic>> fetchSkipTimes({
    required String malId,
    required int episode,
    required double episodeLength,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        AniSkipApi.skipTimesPath(malId, episode),
        queryParameters: {
          'types': AniSkipApi.skipTypes,
          'episodeLength': episodeLength.toStringAsFixed(3),
        },
      );
      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Unexpected AniSkip response payload.',
        );
      }
      return payload;
    } on DioException catch (error) {
      throw NetworkRequestException(
        error.message ?? 'Unable to reach AniSkip.',
      );
    }
  }
}
