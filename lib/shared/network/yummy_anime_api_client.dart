import 'package:dio/dio.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';
import 'package:iris/shared/network/yummy_anime_api.dart';

class YummyAnimeApiClient {
  const YummyAnimeApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<Object?>> searchAnime({required String query}) {
    return _getList(
      YummyAnimeApi.searchPath,
      queryParameters: {'q': query, 'offset': 0, 'limit': 20},
    );
  }

  Future<List<Object?>> fetchVideos({required int animeId}) {
    return _getList(YummyAnimeApi.videosPath(animeId));
  }

  /// The API wraps every answer as `{"response": ...}`.
  Future<List<Object?>> _getList(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final payload = response.data;
      final items = payload is Map ? payload['response'] : null;
      if (items is! List) {
        throw const RemoteResponseException('Unexpected yummy_anime payload.');
      }
      return items;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const ResourceNotFoundException('yummy_anime has no such item.');
      }
      throw mapDioException(error);
    }
  }
}
