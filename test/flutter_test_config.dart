import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:iris/shared/widgets/network_image.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  networkImage = NetworkImage.new;
  await testMain();
}
