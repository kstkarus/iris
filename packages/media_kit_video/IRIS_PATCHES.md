# Iris iOS picture in picture

This directory vendors the MIT-licensed `media_kit_video` 2.0.1 release from
pub.dev. Its Dart API and Android, Windows, Linux and macOS implementations are
unchanged. Keep the upstream LICENSE with this copy.

The iOS bridge follows the AVSampleBufferDisplayLayer approach in
[media-kit PR #1410](https://github.com/media-kit/media-kit/pull/1410), reviewed at
`1eac02c8dabdc2f7be62049fbc0848bbed17dae7`. It uses Iris's existing
`iris/picture_in_picture` channel rather than importing that PR's Android changes
or its Dart API. All native additions live under `ios/Classes/plugin/`, included
by this version's podspec.

- The existing hardware/software renderers publish pixel buffers only while the
  PiP bridge is attached. PiP never opens or decodes a second copy of the media.
- Before PiP starts, the existing player switches its render context to the
  software output, following [PR #206](https://github.com/media-kit/media-kit/pull/206).
  OpenGL ES rendering is not permitted in the iOS background. Once PiP ends,
  the original output is restored while Iris is foregrounded; closing PiP in
  the background leaves the paused software output until the next foreground.
  The source, playback position and saved decoder preference are retained.
- AVKit receives the real playback position, duration, speed and pause state.
  Skip requests are acknowledged after the existing player handles the seek.
- Enter waits for AVKit readiness and reports success only after its start
  callback. Failure/teardown cancel pending work and detach the frame source.
- Native output disposal drains and closes its render context before replying
  to Dart, so a queued PiP renderer change cannot access a released mpv handle.
- Returning to Iris does not force-stop PiP. Restore and Close are distinct.
- Explicit entry uses the existing player button on supported iOS 15+ devices.

The iOS changes have not been validated on a physical iPhone. Build the unsigned
iOS artifact in Actions before release and test video, subtitles, audio,
backgrounding, seeks and restore on a device when one becomes available.
In particular, verify transitions between the OpenGL ES and software outputs,
background playback and the CPU/frame-copy cost; none can be proven by Dart
tests on Windows. AVKit receives copies from a bounded buffer pool so its
asynchronous display cannot read mpv's reused render surfaces.
