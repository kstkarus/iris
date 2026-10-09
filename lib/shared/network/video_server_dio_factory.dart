import 'package:dio/dio.dart';

/// For the players balancers embed (Kodik, Aksor): their pages and APIs
/// are fetched as a browser would, so text comes back as text and no
/// status is an error by itself.
Dio createVideoServerDio() {
  return Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      responseType: ResponseType.plain,
      validateStatus: (_) => true,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0 Safari/537.36',
      },
    ),
  );
}
