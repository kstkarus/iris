/// What mpv reports about decoding the open file; a value it does not
/// report is null.
class PlayerPlaybackDiagnostics {
  const PlayerPlaybackDiagnostics({
    this.hwdecCurrent,
    this.currentVo,
    this.videoCodec,
    this.videoDecoder,
    this.videoDecoderDescription,
  });

  final String? hwdecCurrent;
  final String? currentVo;
  final String? videoCodec;
  final String? videoDecoder;
  final String? videoDecoderDescription;

  bool get isEmpty =>
      _nonBlank(hwdecCurrent) == null &&
      _nonBlank(currentVo) == null &&
      _nonBlank(videoCodec) == null &&
      _nonBlank(videoDecoder) == null &&
      _nonBlank(videoDecoderDescription) == null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PlayerPlaybackDiagnostics &&
        other.hwdecCurrent == hwdecCurrent &&
        other.currentVo == currentVo &&
        other.videoCodec == videoCodec &&
        other.videoDecoder == videoDecoder &&
        other.videoDecoderDescription == videoDecoderDescription;
  }

  @override
  int get hashCode => Object.hash(
    hwdecCurrent,
    currentVo,
    videoCodec,
    videoDecoder,
    videoDecoderDescription,
  );
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
