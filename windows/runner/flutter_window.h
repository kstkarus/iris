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
  bool EnterPictureInPicture();
  void RestorePictureInPicture();
  void SetPictureInPicturePlayer(bool valid, double aspect_ratio);
  void NotifyPictureInPicture(bool active, bool dismissed);
  static LRESULT CALLBACK PictureInPictureChildProc(HWND window, UINT message,
                                                    WPARAM wparam,
                                                    LPARAM lparam,
                                                    UINT_PTR subclass_id,
                                                    DWORD_PTR reference);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // "iris/window": enterFullscreen, exitFullscreen.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      picture_in_picture_channel_;

  bool fullscreen_ = false;
  WINDOWPLACEMENT placement_before_fullscreen_{sizeof(WINDOWPLACEMENT)};

  bool picture_in_picture_ = false;
  bool picture_in_picture_resizing_ = false;
  bool picture_in_picture_player_ = false;
  double picture_in_picture_aspect_ratio_ = 16.0 / 9.0;
  WINDOWPLACEMENT placement_before_picture_in_picture_{sizeof(WINDOWPLACEMENT)};
  LONG_PTR style_before_picture_in_picture_ = 0;
  LONG_PTR ex_style_before_picture_in_picture_ = 0;
  bool topmost_before_picture_in_picture_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
