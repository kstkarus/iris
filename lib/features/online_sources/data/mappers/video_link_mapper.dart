import 'package:iris/features/online_sources/data/models/video_link_dto.dart';
import 'package:iris/features/online_sources/domain/entities/online_stream.dart';

OnlineStream mapVideoLink(VideoLinkDto link) => OnlineStream(
  url: link.url,
  quality: link.quality,
  format: switch (link.kind) {
    VideoLinkKind.hls => OnlineStreamFormat.hls,
    VideoLinkKind.dash => OnlineStreamFormat.dash,
    VideoLinkKind.mp4 => OnlineStreamFormat.mp4,
  },
);
