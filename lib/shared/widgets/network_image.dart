import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Every remote picture in the app goes through this, so covers and avatars
/// are kept on disk between launches. Tests swap it for [NetworkImage]: the
/// disk cache needs platform plugins a widget test does not have.
ImageProvider<Object> Function(String url) networkImage =
    CachedNetworkImageProvider.new;
