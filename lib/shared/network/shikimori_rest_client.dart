import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/shikimori_auth_interceptor.dart';

/// Shikimori's REST API, for what GraphQL lacks: friends, other users'
/// entries and every write. Each call returns the decoded body.
class ShikimoriRestClient {
  const ShikimoriRestClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<Object?> get(String path, {Map<String, Object>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<Object?> post(String path, {Object? data, int? sessionGeneration}) =>
      _send(
        () => _dio.post<dynamic>(
          path,
          data: data,
          options: _sessionOptions(sessionGeneration),
        ),
      );

  Future<Object?> patch(String path, {Object? data, int? sessionGeneration}) =>
      _send(
        () => _dio.patch<dynamic>(
          path,
          data: data,
          options: _sessionOptions(sessionGeneration),
        ),
      );

  Future<Object?> delete(String path, {int? sessionGeneration}) => _send(
    () =>
        _dio.delete<dynamic>(path, options: _sessionOptions(sessionGeneration)),
  );

  Options? _sessionOptions(int? generation) => generation == null
      ? null
      : Options(
          extra: {ShikimoriAuthInterceptor.sessionGenerationKey: generation},
        );

  Future<Object?> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }
}
