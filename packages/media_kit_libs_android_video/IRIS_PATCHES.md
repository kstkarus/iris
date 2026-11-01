# Iris Android media libraries

This is `media_kit_libs_android_video` 1.3.8 from pub.dev; its MIT license is
included. Only the native-library download in `android/build.gradle` changes:
it uses the four SHA-256-pinned `default` artifacts from
[Predidit/libmpv-android-video-build v1.3.1](https://github.com/Predidit/libmpv-android-video-build/releases/tag/v1.3.1).
They are built from mpv `c3ac7f39514c7f45bc38a18e66887240539ee33c` and
FFmpeg `24e860f6d3c4f2ebae65ed7649e2a8860d512879`, with mpv GPL features
and FFmpeg GPL/nonfree features disabled. FFmpeg is built with LGPL version 3.

These libraries require Vulkan 1.1 loader symbols first available on Android
9 (API 28), so the app's minimum Android version is 28. The four architecture
artifacts and their hashes must be updated together.
