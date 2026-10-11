import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
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
      throw mapDioException(error);
    }
  }

  /// The list [field] of the data; throws when it is not a list.
  Future<List<Object?>> queryList(
    String field, {
    required String document,
    Map<String, dynamic>? variables,
  }) async {
    final data = await query(document: document, variables: variables);
    final items = data[field];
    if (items is! List) {
      throw RemoteResponseException('`$field` is not a list.');
    }
    return items;
  }
}
