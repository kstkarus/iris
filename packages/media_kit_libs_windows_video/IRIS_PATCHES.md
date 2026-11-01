# Iris Windows media libraries

This is `media_kit_libs_windows_video` 1.0.11 from pub.dev; its MIT license is
included. The plugin registration and ANGLE libraries are unchanged.

`windows/CMakeLists.txt` downloads the LGPL x86-64 libmpv archive from
[zhongfly/mpv-winbuild 2026-11-01-914a11c30c](https://github.com/zhongfly/mpv-winbuild/releases/tag/2026-11-01-914a11c30c),
verified against its SHA-256. The archive contains the DLL, import library and
matching mpv headers. A version stamp ensures that an existing build replaces
the previous native library instead of keeping the old FFmpeg in a nonempty
cache directory. Header files are also copied into the layout expected by
`media_kit_video`.

This replaces the upstream September 2023 library, which reports FFmpeg 6.0
and corrupts H.264 packets when resuming Alloha's fragmented MP4 streams.
