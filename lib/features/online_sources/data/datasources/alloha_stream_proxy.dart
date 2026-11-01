import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

// Keep the player, WebSocket and signed media requests on the same browser profile.
const allohaUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36';

typedef AllohaSocketConnect =
    Future<WebSocket> Function(Uri uri, Map<String, dynamic> headers);

Future<WebSocket> connectAllohaSocket(
  AllohaSocketConnect? connect,
  Uri uri,
  Map<String, dynamic> headers,
) async {
  final client = connect == null ? (HttpClient()..userAgent = null) : null;
  try {
    final pending = connect != null
        ? connect(uri, headers)
        : WebSocket.connect(
            uri.toString(),
            headers: headers,
            customClient: client,
          );
    try {
      return await pending.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      unawaited(
        pending.then<void>((socket) async {
          try {
            await socket.close().timeout(
              const Duration(seconds: 2),
              onTimeout: () {},
            );
          } on Object {
            // The late socket may already be closed.
          }
        }, onError: (Object _, StackTrace _) {}),
      );
      rethrow;
    }
  } finally {
    client?.close();
  }
}

/// A loopback bridge for Alloha, whose HLS requests require a session header.
class AllohaStreamProxy {
  AllohaStreamProxy({required Dio dio, AllohaSocketConnect? connect})
    : _dio = dio,
      _connect = connect;

  final Dio _dio;
  final AllohaSocketConnect? _connect;
  final _sessions = <String, _Session>{};
  Future<HttpServer>? _server;

  Future<({Map<int, String> qualities, String subtitle})> open({
    required Uri player,
    required Uri socket,
    required String socketId,
    required String guard,
    required String audioId,
    required Map<int, List<Uri>> qualities,
    required Uri subtitle,
  }) async {
    if (socket.scheme != 'wss' ||
        socket.host != player.host ||
        socket.userInfo.isNotEmpty ||
        (socket.hasPort && socket.port != 443) ||
        qualities.isEmpty ||
        socketId.isEmpty ||
        guard.isEmpty) {
      throw const FormatException('Invalid Alloha session.');
    }
    final media = [
      for (final mirrors in qualities.values) ...mirrors,
      subtitle,
    ];
    final allowed = {for (final uri in media) uri.host};
    if (media.any((uri) => !_allowed(uri, allowed))) {
      throw const FormatException('Invalid Alloha media URL.');
    }
    final server = await (_server ??=
        HttpServer.bind(InternetAddress.loopbackIPv4, 0)..then((server) {
          server.listen(_serve);
        }));
    final id = _randomHex(24);
    final session = _Session(
      dio: _dio,
      connect: _connect,
      player: player,
      socketUri: socket,
      socketId: socketId,
      guard: guard,
      audioId: audioId,
      allowed: allowed,
      localBase: Uri.parse('http://127.0.0.1:${server.port}/$id/'),
    );
    try {
      await session.ensureConnected();
      final subtitleLink = session.add(subtitle).toString();
      // A live session is useful only if its playlist is actually accessible.
      await session.checkSubtitle(subtitle);
      Object? failure;
      Uri? playable;
      final unavailable = <int>{};
      for (final entry in qualities.entries) {
        for (final uri in entry.value) {
          try {
            await session.check(uri);
            playable = uri;
            break;
          } on Object catch (error) {
            if (session._edge == null) rethrow;
            failure = error;
          }
        }
        if (playable != null) break;
        unavailable.add(entry.key);
      }
      if (playable == null) {
        throw failure ?? const FormatException('Alloha playlist unavailable.');
      }
      final links = <int, String>{};
      for (final entry in qualities.entries) {
        if (unavailable.contains(entry.key)) continue;
        final mirror =
            entry.value
                .where((uri) => uri.host == playable!.host)
                .firstOrNull ??
            entry.value.firstOrNull;
        if (mirror != null) links[entry.key] = session.add(mirror).toString();
      }
      _sessions[id] = session;
      if (_sessions.length > 32) {
        final oldest = _sessions.entries.reduce(
          (a, b) => a.value.lastUsed.isBefore(b.value.lastUsed) ? a : b,
        );
        _sessions.remove(oldest.key);
        await oldest.value.close();
      }
      return (qualities: links, subtitle: subtitleLink);
    } catch (_) {
      await session.close();
      rethrow;
    }
  }

  Future<void> _serve(HttpRequest request) async {
    try {
      final parts = request.uri.pathSegments;
      final session = parts.length == 3 ? _sessions[parts[0]] : null;
      final uri = session?.resources[parts[1]];
      if (request.method != 'GET' || session == null || uri == null) {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        await session.serve(uri, request);
      }
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.badGateway;
      } on Object {
        // The client can disconnect after a response has started.
      }
    } finally {
      try {
        await request.response.close();
      } on Object {
        // A disconnected player no longer needs the response.
      }
    }
  }

  Future<void> close() async {
    for (final session in _sessions.values) {
      await session.close();
    }
    _sessions.clear();
    final server = _server;
    _server = null;
    if (server != null) await (await server).close(force: true);
  }
}

class _Session {
  _Session({
    required this.dio,
    required this.connect,
    required this.player,
    required this.socketUri,
    required this.socketId,
    required this.guard,
    required this.audioId,
    required this.allowed,
    required this.localBase,
  });

  final Dio dio;
  final AllohaSocketConnect? connect;
  final Uri player;
  final Uri socketUri;
  final String socketId;
  final String guard;
  final String audioId;
  final Set<String> allowed;
  final Uri localBase;
  final resources = <String, Uri>{};
  final _resourceIds = <Uri, String>{};
  DateTime lastUsed = DateTime.now();
  WebSocket? _socket;
  String? _edge;
  Future<void>? _connecting;
  Timer? _idle;
  bool _closed = false;

  Uri add(Uri uri) {
    if (!_allowed(uri, allowed)) {
      throw const FormatException('Invalid media URL.');
    }
    if (resources.length >= 10000) {
      throw const FormatException('Playlist is too large.');
    }
    final id = _resourceIds.putIfAbsent(uri, () {
      final value = '${resources.length}';
      resources[value] = uri;
      return value;
    });
    final name = uri.pathSegments.lastOrNull;
    return localBase.resolve(
      '$id/${name == null || name.isEmpty ? 'resource' : Uri.encodeComponent(name)}',
    );
  }

  Future<void> ensureConnected() async {
    if (_closed) throw StateError('Alloha session closed.');
    lastUsed = DateTime.now();
    _idle?.cancel();
    _idle = Timer(const Duration(minutes: 3), () {
      unawaited(_disconnect());
    });
    if (_edge != null) return;
    await (_connecting ??= _openSocket().whenComplete(
      () => _connecting = null,
    ));
  }

  Future<void> _openSocket() async {
    await _disconnect();
    final now = DateTime.now().millisecondsSinceEpoch;
    final uri = socketUri.replace(
      queryParameters: {
        ...socketUri.queryParameters,
        'sid': socketId,
        'v': '2.1',
        't': '$now',
      },
    );
    final ws = await connectAllohaSocket(connect, uri, {
      'Origin': player.origin,
      'User-Agent': allohaUserAgent,
    });
    if (_closed) {
      await ws.close();
      throw StateError('Alloha session closed.');
    }
    _socket = ws;
    ws.pingInterval = const Duration(seconds: 20);
    final ready = Completer<void>();
    ws.listen(
      (message) {
        try {
          final data = jsonDecode(message as String);
          if (data is Map &&
              data['type'] == 'config_update' &&
              data['edge_hash'] is String &&
              (data['edge_hash'] as String).isNotEmpty) {
            _edge = data['edge_hash'] as String;
            if (!ready.isCompleted) ready.complete();
          }
        } on Object {
          /* Ignore unrelated socket messages. */
        }
      },
      onError: (Object error) {
        if (!ready.isCompleted) ready.completeError(error);
      },
      onDone: () {
        if (identical(_socket, ws)) {
          _socket = null;
          _edge = null;
        }
        if (!ready.isCompleted) {
          ready.completeError(
            FormatException(
              'Alloha session closed (${ws.closeCode} ${ws.closeReason}).',
            ),
          );
        }
      },
    );
    ws.add(
      jsonEncode({
        'type': 'playback_start',
        'current_time': 0,
        'resolution': '720',
        'track_id': audioId,
        'speed': 1,
        'subtitle': -1,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    await ready.future.timeout(const Duration(seconds: 15));
  }

  Future<void> _disconnect() async {
    final ws = _socket;
    _socket = null;
    _edge = null;
    if (ws != null) {
      try {
        await ws.close().timeout(const Duration(seconds: 2), onTimeout: () {});
      } on Object {
        // The peer may already have disconnected.
      }
    }
  }

  Future<Response<ResponseBody>> _fetch(Uri uri, {String? range}) async {
    if (!_allowed(uri, allowed)) {
      throw const FormatException('Invalid media URL.');
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      await ensureConnected();
      final socket = _socket;
      final response = await dio.getUri<ResponseBody>(
        uri,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
          headers: {
            'Origin': player.origin,
            'Referer': player.toString(),
            'User-Agent': allohaUserAgent,
            'Authorizations': 'Bearer $guard',
            'Accepts-Controls': _edge,
            'Range': ?range,
          },
        ),
      );
      if ((response.statusCode == 401 ||
              response.statusCode == 403 ||
              response.statusCode == 410) &&
          attempt == 0) {
        await response.data?.stream.drain<void>();
        if (identical(_socket, socket)) await _disconnect();
        continue;
      }
      return response;
    }
    throw const FormatException('Alloha session refused.');
  }

  Future<void> check(Uri uri) async {
    final response = await _fetch(uri);
    if (response.statusCode != 200) {
      await response.data?.stream.drain<void>();
      throw FormatException(
        'Alloha playlist refused (HTTP ${response.statusCode}).',
      );
    }
    final text = await _readText(response);
    if (!text.startsWith('#EXTM3U')) {
      throw const FormatException('Invalid Alloha playlist.');
    }
  }

  Future<void> checkSubtitle(Uri uri) async {
    final response = await _fetch(uri);
    if (response.statusCode != 200) {
      await response.data?.stream.drain<void>();
      throw FormatException(
        'Alloha subtitle refused (HTTP ${response.statusCode}).',
      );
    }
    final text = await _readText(response);
    if (!text.trimLeft().startsWith('WEBVTT')) {
      throw const FormatException('Invalid Alloha subtitle.');
    }
  }

  Future<String> _readText(Response<ResponseBody> response) async {
    final bytes = <int>[];
    await for (final chunk in response.data!.stream) {
      bytes.addAll(chunk);
      if (bytes.length > 2 * 1024 * 1024) {
        throw const FormatException('Playlist is too large.');
      }
    }
    return utf8.decode(bytes);
  }

  Future<void> serve(Uri uri, HttpRequest request) async {
    final isPlaylist = uri.path.toLowerCase().endsWith('.m3u8');
    final response = await _fetch(
      uri,
      range: isPlaylist ? null : request.headers.value('range'),
    );
    final status = response.statusCode ?? 502;
    request.response.statusCode = status;
    request.response.headers.set('Cache-Control', 'no-store');
    if (status < 200 || status >= 300 || response.data == null) {
      await response.data?.stream.drain<void>();
      return;
    }
    if (isPlaylist && status != HttpStatus.ok) {
      await response.data!.stream.drain<void>();
      request.response.statusCode = HttpStatus.badGateway;
      return;
    }
    for (final header in [
      'content-type',
      if (!isPlaylist) 'content-range',
      if (!isPlaylist) 'accept-ranges',
    ]) {
      final value = response.headers.value(header);
      if (value != null) request.response.headers.set(header, value);
    }
    if (isPlaylist) {
      final text = await _readText(response);
      if (!text.startsWith('#EXTM3U')) {
        throw const FormatException('Invalid Alloha playlist.');
      }
      final lines = text
          .split('\n')
          .map((line) {
            final trimmed = line.trim();
            if (trimmed.isEmpty) return line;
            if (!trimmed.startsWith('#')) return _rewrite(uri, trimmed);
            return line.replaceAllMapped(
              RegExp(r'URI="([^"]+)"'),
              (match) => 'URI="${_rewrite(uri, match.group(1)!)}"',
            );
          })
          .join('\n');
      request.response.headers.contentType = ContentType(
        'application',
        'vnd.apple.mpegurl',
        charset: 'utf-8',
      );
      request.response.write(lines);
    } else {
      await request.response.addStream(response.data!.stream);
    }
  }

  String _rewrite(Uri base, String reference) {
    final local = add(_resolve(base, reference));
    final digest = sha256.convert(utf8.encode(reference)).toString();
    return '../${local.pathSegments[1]}/$digest-${Uri.encodeComponent(local.pathSegments.last)}';
  }

  Future<void> close() async {
    _closed = true;
    _idle?.cancel();
    await _disconnect();
  }
}

Uri _resolve(Uri base, String reference) {
  final parsed = Uri.tryParse(reference);
  if (reference.startsWith('//')) return Uri.parse('${base.scheme}:$reference');
  if (parsed != null && (parsed.isScheme('http') || parsed.isScheme('https'))) {
    return parsed;
  }
  if (parsed != null && !parsed.hasScheme) return base.resolveUri(parsed);
  return base.resolve('./$reference');
}

bool _allowed(Uri uri, Set<String> hosts) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' &&
      hosts.contains(host) &&
      uri.userInfo.isEmpty &&
      (!uri.hasPort || uri.port == 443) &&
      host.contains('.') &&
      InternetAddress.tryParse(host) == null &&
      !host.endsWith('.local') &&
      !host.endsWith('.localhost') &&
      !host.endsWith('.internal');
}

String _randomHex(int bytes) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
