import 'package:dio/dio.dart';

import 'package:iris/shared/network/shikimori_api.dart';

Dio createDio() {
  return Dio(
    BaseOptions(
      baseUrl: ShikimoriApi.baseUrl,
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );
}
