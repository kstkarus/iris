import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/nyaa_api.dart';

class NyaaApiClient {
  const NyaaApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> fetchSources({required String query}) async {
    try {
      final response = await _dio.get<dynamic>(
        NyaaApi.searchPath,
        queryParameters: {
          'q': query,
          'category': NyaaApi.animeCategory,
          // A search returns one page (75); the best-seeded rather than the
          // newest, as the list is sorted by seeders anyway.
          'sort': 'seeders',
          'order': 'desc',
        },
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Unexpected nyaa response payload.',
        );
      }

      return payload;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
