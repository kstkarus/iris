import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// An in-memory [FlutterSecureStorage]: read, write and delete by key.
class FakeSecureStorage implements FlutterSecureStorage {
  FakeSecureStorage([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;
  bool failReads = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    final key = invocation.namedArguments[#key] as String?;
    switch (invocation.memberName) {
      case #read:
        if (failReads) return Future<String?>.error(Exception('keystore'));
        return Future<String?>.value(values[key]);
      case #write:
        final value = invocation.namedArguments[#value] as String?;
        if (value == null) {
          values.remove(key);
        } else {
          values[key!] = value;
        }
        return Future<void>.value();
      case #delete:
        values.remove(key);
        return Future<void>.value();
    }
    return super.noSuchMethod(invocation);
  }
}
