import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris/shared/network/dio_exception_mapper.dart';
import 'package:iris/shared/network/network_exceptions.dart';

void main() {
  test('maps timeouts and connection errors to a network failure', () {
    for (final type in [
      DioExceptionType.connectionTimeout,
      DioExceptionType.sendTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.transformTimeout,
      DioExceptionType.connectionError,
    ]) {
      expect(
        mapDioException(_error(type, message: 'slow link')),
        isA<NetworkRequestException>().having(
          (exception) => exception.message,
          'message',
          'slow link',
        ),
      );
    }
  });

  test('maps a bad response to a remote failure with its status code', () {
    final response = Response<dynamic>(
      requestOptions: RequestOptions(path: '/test'),
      statusCode: 503,
    );

    expect(
      mapDioException(_error(DioExceptionType.badResponse, response: response)),
      isA<RemoteResponseException>().having(
        (exception) => exception.statusCode,
        'statusCode',
        503,
      ),
    );
  });

  test('maps a bad response without a status to a remote failure', () {
    expect(
      mapDioException(_error(DioExceptionType.badResponse)),
      isA<RemoteResponseException>(),
    );
  });

  test('maps a cancelled request to a network failure', () {
    expect(
      mapDioException(_error(DioExceptionType.cancel)),
      isA<NetworkRequestException>(),
    );
  });

  test('maps certificate and unknown failures to a network failure', () {
    for (final type in [
      DioExceptionType.badCertificate,
      DioExceptionType.unknown,
    ]) {
      expect(mapDioException(_error(type)), isA<NetworkRequestException>());
    }
  });
}

DioException _error(
  DioExceptionType type, {
  String? message,
  Response<dynamic>? response,
}) {
  return DioException(
    requestOptions: RequestOptions(path: '/test'),
    type: type,
    message: message,
    response: response,
  );
}
