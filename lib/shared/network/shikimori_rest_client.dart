import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';

/// Shikimori's REST API, for what GraphQL lacks: friends, other users'
/// entries and every write. Each call returns the decoded body.
class ShikimoriRestClient {
  const ShikimoriRestClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Object?> get(String path, {Map<String, Object>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Object?> post(String path, {Object? data}) =>
      _send(() => _dio.post<dynamic>(path, data: data));

  Future<Object?> patch(String path, {Object? data}) =>
      _send(() => _dio.patch<dynamic>(path, data: data));

  Future<Object?> delete(String path) =>
      _send(() => _dio.delete<dynamic>(path));

  Future<Object?> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
