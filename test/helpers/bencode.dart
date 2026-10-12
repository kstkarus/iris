import 'dart:convert';
import 'dart:typed_data';

/// Bencode, keys sorted as the format requires.
Uint8List encodeBencode(Object value) {
  final out = BytesBuilder();
  void write(Object value) {
    switch (value) {
      case int():
        out.add(ascii.encode('i${value}e'));
      case String():
        write(Uint8List.fromList(utf8.encode(value)));
      case Uint8List():
        out
          ..add(ascii.encode('${value.length}:'))
          ..add(value);
      case List<Object?>():
        out.addByte(0x6c);
        for (final item in value) {
          write(item!);
        }
        out.addByte(0x65);
      case Map<String, Object?>():
        out.addByte(0x64);
        for (final key in value.keys.toList()..sort()) {
          write(key);
          write(value[key]!);
        }
        out.addByte(0x65);
      default:
        throw ArgumentError(value);
    }
  }

  write(value);
  return out.toBytes();
}

/// A small single-file `.torrent` named [name].
Uint8List torrentFileBytes(String name, {int length = 1024}) => encodeBencode({
  'announce': 'udp://tracker.example:6969',
  'info': {
    'length': length,
    'name': name,
    'piece length': 16384,
    'pieces': Uint8List(20),
  },
});
