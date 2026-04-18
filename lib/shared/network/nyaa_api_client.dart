import 'package:dio/dio.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/nyaa_api.dart';

class NyaaApiClient {
  const NyaaApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> fetchSources({required String query}) async {
    try {
      final response = await _dio.get<dynamic>(
        NyaaApi.searchPath,
        queryParameters: {'q': query},
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Unexpected nyaa response payload.',
        );
      }

      return payload;
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }
}

Exception _mapDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return NetworkRequestException(
        error.message ?? 'Unable to reach the remote service.',
      );
    case DioExceptionType.badResponse:
      return RemoteResponseException(
        'Remote service responded with ${error.response?.statusCode ?? 'an invalid status'}.',
      );
    case DioExceptionType.cancel:
      return const NetworkRequestException('The request was cancelled.');
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return NetworkRequestException(
        error.message ?? 'Unexpected network error.',
      );
  }
}
