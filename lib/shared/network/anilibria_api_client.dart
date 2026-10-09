import 'package:dio/dio.dart';

import 'package:iris/shared/network/anilibria_api.dart';
import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';

class AnilibriaApiClient {
  const AnilibriaApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  Future<List<Object?>> searchReleases({required String query}) async {
    final payload = await _get(
      AnilibriaApi.searchPath,
      queryParameters: {'query': query},
    );
    if (payload is! List) {
      throw const RemoteResponseException(
        'Unexpected AniLibria search payload.',
      );
    }
    return payload;
  }

  Future<Map<String, dynamic>> fetchRelease({required int releaseId}) {
    return _getObject(AnilibriaApi.releasePath(releaseId));
  }

  Future<Map<String, dynamic>> fetchEpisode({required String episodeId}) {
    return _getObject(AnilibriaApi.episodePath(episodeId));
  }

  Future<Map<String, dynamic>> _getObject(String path) async {
    final payload = await _get(path);
    if (payload is! Map<String, dynamic>) {
      throw const RemoteResponseException('Unexpected AniLibria payload.');
    }
    return payload;
  }

  Future<Object?> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return response.data;
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        throw const ResourceNotFoundException('AniLibria has no such item.');
      }
      throw mapDioException(error);
    }
  }
}
