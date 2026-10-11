import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A reply for [FakeHttpAdapter]: [body] goes out as JSON.
class FakeReply {
  const FakeReply(
    this.status, [
    this.body = const <String, dynamic>{},
    this.headers = const {},
  ]) : raw = false;

  /// A reply whose [body] goes out as it is, such as a page or a script.
  const FakeReply.text(this.status, String this.body, {this.headers = const {}})
    : raw = true;

  final int status;
  final Object body;
  final Map<String, List<String>> headers;
  final bool raw;
}

/// Answers Dio requests with [respond], and keeps what was asked.
///
/// A [DioException] thrown by [respond] reaches the caller as a transport
/// failure, such as a timeout.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.respond);

  final FutureOr<FakeReply> Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final reply = await respond(options);
    return ResponseBody.fromString(
      reply.raw ? reply.body as String : jsonEncode(reply.body),
      reply.status,
      headers: {
        Headers.contentTypeHeader: [
          reply.raw ? Headers.textPlainContentType : Headers.jsonContentType,
        ],
        ...reply.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A plain [Dio] whose requests [respond] answers.
Dio fakeDio(FutureOr<FakeReply> Function(RequestOptions options) respond) {
  return Dio()..httpClientAdapter = FakeHttpAdapter(respond);
}

/// A file from `test/fixtures/`, as text.
String readFixture(String path) =>
    File('test/fixtures/$path').readAsStringSync();
