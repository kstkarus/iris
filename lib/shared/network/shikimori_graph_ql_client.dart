import 'package:dio/dio.dart';

import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/shikimori_api.dart';

class ShikimoriGraphQlClient {
  const ShikimoriGraphQlClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Map<String, dynamic>> query({
    required String document,
    Map<String, dynamic>? variables,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ShikimoriApi.graphQlPath,
        data: {
          'query': document,
          if (variables != null && variables.isNotEmpty) 'variables': variables,
        },
      );

      final payload = response.data;
      if (payload is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'Unexpected GraphQL response payload.',
        );
      }

      final errors = payload['errors'];
      if (errors is List && errors.isNotEmpty) {
        final firstError = errors.first;
        final message = firstError is Map<String, dynamic>
            ? firstError['message']?.toString()
            : null;

        throw RemoteResponseException(message ?? 'GraphQL request failed.');
      }

      final data = payload['data'];
      if (data is! Map<String, dynamic>) {
        throw const RemoteResponseException(
          'GraphQL response does not contain a valid data object.',
        );
      }

      return data;
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
    case DioExceptionType.transformTimeout:
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
