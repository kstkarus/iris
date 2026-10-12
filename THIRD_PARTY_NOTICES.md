# Third-party notices

## anicli-api

The online source extractors for AniLibria, yummy_anime, Kodik and Aksor in `lib/features/online_sources/data/` are Dart ports of [anicli-api](https://github.com/vypivshiy/anicli-api) 0.12.0. Each ported file names the module it follows.

```
MIT License

Copyright (c) 2022 vypivshiy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

## Fonts

Geist and Geist Mono (`assets/fonts/`, license in `assets/fonts/Geist-OFL.txt`) and Noto Sans CJK JP are licensed under the SIL Open Font License 1.1.

## Bundled native libraries

Release builds include native libraries that the Flutter packages in `pubspec.yaml` download at build time, under their own licenses:

- **mpv** and **FFmpeg**, through `media_kit`: LGPL or GPL, depending on the build;
- **libtorrent**, through `libtorrent_flutter`: BSD.

Each Dart and Flutter package carries its own license in its source.
