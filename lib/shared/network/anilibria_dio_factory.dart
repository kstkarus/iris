import 'package:dio/dio.dart';

import 'package:iris/shared/network/anilibria_api.dart';

Dio createAnilibriaDio() {
  return Dio(
    BaseOptions(
      baseUrl: AnilibriaApi.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    ),
  );
}
