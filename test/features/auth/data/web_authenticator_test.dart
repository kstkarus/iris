import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris/features/auth/data/datasources/web_authenticator.dart';

void main() {
  test('the landing page survives Latin-1, as the plugin sends it', () {
    final page = asciiHtml('<p>Вход — ok</p>');

    expect(page, '<p>&#1042;&#1093;&#1086;&#1076; &#8212; ok</p>');
    expect(() => latin1.encode(page), returnsNormally);
  });
}
