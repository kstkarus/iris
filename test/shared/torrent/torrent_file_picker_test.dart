import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

import 'package:iris/shared/torrent/torrent_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('iris_torrent_picker_');
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'the Android picker enforces the limit before returning bytes',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('iris/torrent_file_picker');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'pickTorrentFile');
        expect(call.arguments, maxTorrentFileBytes);
        throw PlatformException(code: 'file_too_large');
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

      await expectLater(
        pickTorrentFile(),
        throwsA(isA<TorrentFileTooLargeException>()),
      );
    },
  );

  test('reads files within the byte limit', () async {
    final file = File(path.join(tempDir.path, 'small.torrent'));
    final data = Uint8List.fromList([1, 2, 3, 4, 5]);
    await file.writeAsBytes(data);

    final result = await readTorrentFileBytes(XFile(file.path), maxBytes: 5);

    expect(result, data);
  });

  test('rejects an oversized file without reading it into memory', () async {
    final file = File(path.join(tempDir.path, 'large.mkv'));
    await file.writeAsBytes(Uint8List(32));

    await expectLater(
      readTorrentFileBytes(XFile(file.path), maxBytes: 16),
      throwsA(isA<TorrentFileTooLargeException>()),
    );
  });

  test(
    'rejects a stream that exceeds the limit when length is unavailable',
    () async {
      final fake = _UnsupportedLengthXFile(Uint8List(32));

      await expectLater(
        readTorrentFileBytes(fake, maxBytes: 16),
        throwsA(isA<TorrentFileTooLargeException>()),
      );
    },
  );
}

class _UnsupportedLengthXFile extends XFile {
  _UnsupportedLengthXFile(this._data) : super.fromData(_data);

  final Uint8List _data;

  @override
  Future<int> length() => Future<int>.error(UnsupportedError('no length'));

  @override
  Stream<Uint8List> openRead([int? start, int? end]) async* {
    final s = start ?? 0;
    final e = (end ?? _data.length).clamp(s, _data.length);
    yield _data.sublist(s, e);
  }
}
