import 'package:flutter/foundation.dart';

/// Whether the overlay shows technical playback details (peers, decoder,
/// codecs, memory). Off by default: overlays should defer to the video.
/// Kept for the app session so it survives switching episodes.
final playerDetailedStatsEnabled = ValueNotifier<bool>(false);
