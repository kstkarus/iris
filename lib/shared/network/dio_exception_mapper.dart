import 'package:dio/dio.dart';

import 'package:iris/shared/network/network_exceptions.dart';

/// Maps a failed Dio request onto the app's network and response exceptions.
Exception mapDioException(DioException error) {
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
