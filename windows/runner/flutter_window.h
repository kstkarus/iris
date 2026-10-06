#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // Covers the monitor without a frame, or restores the window as it was.
  void SetFullscreen(bool fullscreen);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // "iris/window": enterFullscreen, exitFullscreen.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  bool fullscreen_ = false;
  WINDOWPLACEMENT placement_before_fullscreen_{sizeof(WINDOWPLACEMENT)};

  // While the frame style changes, Windows would paint the old frame
  // unthemed (a classic title bar) until the window gets its new bounds.
  bool suppress_frame_paint_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
