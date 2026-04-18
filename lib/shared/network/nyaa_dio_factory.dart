import 'package:dio/dio.dart';

import 'package:iris/shared/network/nyaa_api.dart';

Dio createNyaaDio() {
  return Dio(
    BaseOptions(
      baseUrl: NyaaApi.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
}
