# Iris iOS media libraries

This is `media_kit_libs_ios_video` 1.1.4 from pub.dev; its MIT license is
included. The Swift plugin and framework layout are unchanged.

`ios/Makefile` downloads the SHA-256-pinned `ios-universal-video-default`
archive from [demoofbug/libmpv-darwin-build v0.41.0+1](https://github.com/demoofbug/libmpv-darwin-build/releases/tag/v0.41.0%2B1).
It contains mpv 0.41.0 and FFmpeg 9.0.2, replacing the upstream mpv 0.36.0 /
FFmpeg 6.0 build. Device arm64 and simulator arm64/x86-64 slices are included.
The `video-default` flavor keeps GPL and nonfree features disabled.

The existing versioned archive and framework extraction rules replace cached
frameworks when the pinned version changes. A failed download or checksum
now also stops pod installation rather than allowing stale frameworks.
