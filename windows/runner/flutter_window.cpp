#include "flutter_window.h"

#include <commctrl.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <algorithm>
#include <cmath>
#include <optional>

#include "flutter/generated_plugin_registrant.h"
#include "player_media_controls.h"

namespace {
constexpr UINT kStartPictureInPictureDrag = WM_APP + 1;
constexpr UINT kQuitForAppUpdate = WM_APP + 2;
constexpr double kDefaultPictureInPictureAspectRatio = 16.0 / 9.0;
constexpr double kMinimumPictureInPictureAspectRatio = 1.0 / 2.38;
constexpr double kMaximumPictureInPictureAspectRatio = 2.38;
constexpr int kMinimumPictureInPictureWidth = 240;
constexpr int kMinimumPictureInPictureHeight = 135;

using window_placement::FitPictureInPictureClientSize;
using window_placement::PictureInPictureSize;

struct PictureInPictureLimits {
  RECT work_area;
  int minimum_width;
  int minimum_height;
  int maximum_width;
  int maximum_height;
};

UINT GetWindowDpi(HWND window) {
  const UINT dpi = GetDpiForWindow(window);
  return dpi == 0 ? 96 : dpi;
}

int ScaleForDpi(int logical_size, UINT dpi) {
  return static_cast<int>(std::lround(logical_size * (dpi / 96.0)));
}

int MinimumPictureInPictureWidth(double aspect, UINT dpi) {
  return std::max(ScaleForDpi(kMinimumPictureInPictureWidth, dpi),
                  static_cast<int>(std::ceil(
                      ScaleForDpi(kMinimumPictureInPictureHeight, dpi) * aspect)));
}

bool SetWindowLongPtrValue(HWND window, int index, LONG_PTR value) {
  SetLastError(ERROR_SUCCESS);
  const LONG_PTR previous = SetWindowLongPtr(window, index, value);
  return previous != 0 || GetLastError() == ERROR_SUCCESS;
}

bool GetPictureInPictureWorkArea(HWND window, const RECT* bounds,
                                 RECT* work_area) {
  const HMONITOR monitor =
      bounds == nullptr ? MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST)
                        : MonitorFromRect(bounds, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{sizeof(MONITORINFO)};
  if (monitor == nullptr || !GetMonitorInfo(monitor, &monitor_info)) {
    return false;
  }
  *work_area = monitor_info.rcWork;
  return true;
}

bool GetPictureInPictureLimits(HWND window, const RECT* bounds, double aspect,
                               UINT dpi, PictureInPictureLimits* limits) {
  if (!GetPictureInPictureWorkArea(window, bounds, &limits->work_area)) {
    return false;
  }
  const int available_width = limits->work_area.right - limits->work_area.left;
  const int available_height = limits->work_area.bottom - limits->work_area.top;
  if (available_width < 1 || available_height < 1) return false;

  limits->maximum_width = std::min(
      available_width, static_cast<int>(std::floor(available_height * aspect)));
  limits->maximum_width = std::max(1, limits->maximum_width);
  limits->maximum_height =
      std::min(available_height,
               static_cast<int>(std::floor(limits->maximum_width / aspect)));
  limits->maximum_height = std::max(1, limits->maximum_height);

  limits->minimum_width =
      std::clamp(MinimumPictureInPictureWidth(aspect, dpi), 1,
                 limits->maximum_width);
  limits->minimum_height =
      std::max(1, static_cast<int>(std::floor(limits->minimum_width / aspect)));
  return true;
}

bool ClampPictureInPictureBounds(HWND window, double aspect, RECT* bounds) {
  RECT work{};
  if (!GetPictureInPictureWorkArea(window, bounds, &work)) return false;
  int width = bounds->right - bounds->left;
  int height = bounds->bottom - bounds->top;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;
  if (width > work_width || height > work_height) {
    const auto size =
        FitPictureInPictureClientSize(width, aspect, work_width, work_height);
    width = size.width;
    height = size.height;
  }
  bounds->left = std::clamp(bounds->left, work.left, work.right - width);
  bounds->top = std::clamp(bounds->top, work.top, work.bottom - height);
  bounds->right = bounds->left + width;
  bounds->bottom = bounds->top + height;
  return true;
}

const flutter::EncodableMap* GetArguments(
    const flutter::MethodCall<flutter::EncodableValue>& call) {
  if (call.arguments() == nullptr) return nullptr;
  return std::get_if<flutter::EncodableMap>(call.arguments());
}

double GetNumber(const flutter::EncodableMap* arguments, const char* key,
                 double fallback) {
  if (arguments == nullptr) return fallback;
  auto value = arguments->find(flutter::EncodableValue(key));
  if (value == arguments->end()) return fallback;
  if (const auto* number = std::get_if<double>(&value->second)) return *number;
  if (const auto* number = std::get_if<int32_t>(&value->second)) return *number;
  if (const auto* number = std::get_if<int64_t>(&value->second)) {
    return static_cast<double>(*number);
  }
  return fallback;
}

constexpr COLORREF ColorRefFromArgb(uint32_t argb) {
  return RGB((argb >> 16) & 0xff, (argb >> 8) & 0xff, argb & 0xff);
}

static_assert(ColorRefFromArgb(0xff123456) == 0x00563412);

COLORREF GetTitleBarColor(const flutter::EncodableMap& arguments,
                          const char* key) {
  const auto entry = arguments.find(flutter::EncodableValue(key));
  if (entry != arguments.end()) {
    if (const auto* color = std::get_if<int32_t>(&entry->second)) {
      return ColorRefFromArgb(static_cast<uint32_t>(*color));
    }
    if (const auto* color = std::get_if<int64_t>(&entry->second)) {
      return ColorRefFromArgb(static_cast<uint32_t>(*color));
    }
  }
  return 0xffffffff;  // DWM default when a custom color is omitted.
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  Destroy();
}

bool FlutterWindow::Create(const std::wstring& title) {
  placement_path_ = window_placement::StatePath();
  window_state_ = window_placement::Load(placement_path_);
  return Win32Window::Create(title, window_state_.main);
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  media_controls_ = std::make_unique<PlayerMediaControls>(
      GetHandle(), flutter_controller_->engine()->messenger());

  app_update_channel_ = CreateAppUpdateChannel(
      flutter_controller_->engine()->messenger(), [this]() {
        HWND window = GetHandle();
        if (window != nullptr && IsWindow(window)) {
          PostMessage(window, kQuitForAppUpdate, 0, 0);
        }
      });

  window_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "iris/window",
          &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() == "enterFullscreen") {
          SetFullscreen(true);
          result->Success();
        } else if (call.method_name() == "exitFullscreen") {
          SetFullscreen(false);
          result->Success();
        } else if (call.method_name() == "setTitleBarTheme") {
          const auto* arguments = GetArguments(call);
          const auto dark =
              arguments ? arguments->find(flutter::EncodableValue("dark"))
                        : flutter::EncodableMap::const_iterator{};
          if (!arguments || dark == arguments->end() ||
              !std::holds_alternative<bool>(dark->second)) {
            result->Error("invalid_theme", "Expected a dark mode flag.");
            return;
          }
          SetTitleBarTheme({std::get<bool>(dark->second),
                            GetTitleBarColor(*arguments, "captionColor"),
                            GetTitleBarColor(*arguments, "textColor"),
                            GetTitleBarColor(*arguments, "borderColor")});
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  picture_in_picture_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "iris/picture_in_picture",
          &flutter::StandardMethodCodec::GetInstance());
  picture_in_picture_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        const auto* arguments = GetArguments(call);
        if (call.method_name() == "isSupported") {
          result->Success(
              flutter::EncodableValue(picture_in_picture_resizing_));
        } else if (call.method_name() == "setPlayer") {
          const double ratio = GetNumber(arguments, "aspectRatio", 0);
          SetPictureInPicturePlayer(
              true, std::isfinite(ratio) && ratio > 0 ? ratio : 0);
          result->Success();
        } else if (call.method_name() == "clearPlayer") {
          const bool was_active = picture_in_picture_;
          if (was_active) RestorePictureInPicture();
          SetPictureInPicturePlayer(false, 0);
          if (was_active) NotifyPictureInPicture(false, false);
          result->Success();
        } else if (call.method_name() == "enter") {
          result->Success(flutter::EncodableValue(EnterPictureInPicture()));
        } else if (call.method_name() == "restore") {
          const bool was_active = picture_in_picture_;
          if (was_active) RestorePictureInPicture();
          if (was_active) NotifyPictureInPicture(false, false);
          result->Success();
        } else if (call.method_name() == "dismiss") {
          const bool was_active = picture_in_picture_;
          if (was_active) RestorePictureInPicture();
          if (was_active) NotifyPictureInPicture(false, true);
          result->Success();
        } else if (call.method_name() == "startDragging") {
          HWND window = GetHandle();
          if (picture_in_picture_ && window != nullptr && IsWindow(window)) {
            PostMessage(window, kStartPictureInPictureDrag, 0, 0);
          }
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  picture_in_picture_resizing_ =
      SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(),
                        PictureInPictureChildProc, 1,
                        reinterpret_cast<DWORD_PTR>(this)) != FALSE;

  flutter_controller_->engine()->SetNextFrameCallback([this]() {
    track_placement_ = Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  SaveWindowPlacement(GetHandle());
  track_placement_ = false;
  picture_in_picture_channel_ = nullptr;
  media_controls_ = nullptr;
  app_update_channel_ = nullptr;
  window_channel_ = nullptr;
  if (flutter_controller_) {
    if (picture_in_picture_resizing_) {
      RemoveWindowSubclass(flutter_controller_->view()->GetNativeWindow(),
                           PictureInPictureChildProc, 1);
      picture_in_picture_resizing_ = false;
    }
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::SaveWindowPlacement(HWND window) {
  if (!track_placement_ || changing_picture_in_picture_ || window == nullptr) {
    return;
  }

  const bool minimized = IsIconic(window) != FALSE;
  RECT bounds{};
  const bool have_bounds = !minimized && GetWindowRect(window, &bounds);
  if (picture_in_picture_ && have_bounds && bounds.right > bounds.left) {
    window_state_.pip = window_placement::PictureInPicturePlacement{
        bounds.left, bounds.top, bounds.right - bounds.left};
  }

  WINDOWPLACEMENT current{sizeof(WINDOWPLACEMENT)};
  const WINDOWPLACEMENT* placement = nullptr;
  if (fullscreen_) {
    placement = &placement_before_fullscreen_;
  } else if (picture_in_picture_) {
    placement = &placement_before_picture_in_picture_;
  } else if (!minimized && GetWindowPlacement(window, &current)) {
    placement = &current;
  }

  if (placement != nullptr) {
    const RECT& normal = placement->rcNormalPosition;
    MONITORINFO monitor{sizeof(MONITORINFO)};
    GetMonitorInfo(MonitorFromRect(&normal, MONITOR_DEFAULTTONEAREST), &monitor);
    auto main = window_placement::MainFromWindowPlacement(*placement, monitor);
    if (placement == &current && !main.maximized && have_bounds) {
      main.normal_bounds = bounds;
    }
    window_state_.main = main;
  }
  if (window_state_.main || window_state_.pip) {
    window_placement::Save(placement_path_, window_state_);
  }
}

void FlutterWindow::SetFullscreen(bool fullscreen) {
  HWND window = GetHandle();
  if (window == nullptr) {
    return;
  }
  if (picture_in_picture_) {
    RestorePictureInPicture();
    NotifyPictureInPicture(false, false);
  }
  if (fullscreen == fullscreen_) return;

  LONG_PTR style = GetWindowLongPtr(window, GWL_STYLE);
  if (fullscreen) {
    if (!GetWindowPlacement(window, &placement_before_fullscreen_)) return;
    MONITORINFO monitor{sizeof(MONITORINFO)};
    if (!GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                        &monitor)) {
      return;
    }
    fullscreen_ = true;
    const RECT& bounds = monitor.rcMonitor;
    SetWindowLongPtr(window, GWL_STYLE, style & ~WS_OVERLAPPEDWINDOW);
    SetWindowPos(window, HWND_TOP, bounds.left, bounds.top,
                 bounds.right - bounds.left, bounds.bottom - bounds.top,
                 SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  } else {
    SetWindowLongPtr(window, GWL_STYLE, style | WS_OVERLAPPEDWINDOW);
    UpdateTheme(window);
    // Back to the same size, position and maximized state.
    SetWindowPlacement(window, &placement_before_fullscreen_);
    SetWindowPos(window, nullptr, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOOWNERZORDER |
                     SWP_FRAMECHANGED);
    fullscreen_ = false;
  }
  RedrawWindow(window, nullptr, nullptr,
               RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN);
}

bool FlutterWindow::EnterPictureInPicture() {
  HWND window = GetHandle();
  if (window == nullptr || !IsWindow(window) || !picture_in_picture_player_ ||
      !picture_in_picture_resizing_) {
    return false;
  }
  if (picture_in_picture_) return true;

  placement_before_picture_in_picture_.length = sizeof(WINDOWPLACEMENT);
  if (!GetWindowPlacement(window, &placement_before_picture_in_picture_))
    return false;
  style_before_picture_in_picture_ = GetWindowLongPtr(window, GWL_STYLE);
  ex_style_before_picture_in_picture_ = GetWindowLongPtr(window, GWL_EXSTYLE);
  topmost_before_picture_in_picture_ =
      (ex_style_before_picture_in_picture_ & WS_EX_TOPMOST) != 0;

  // Keep the window's normal DWM frame style; only its client calculation
  // changes in PiP. Swapping to a popup needlessly changes frame rendering.
  const LONG_PTR style =
      (style_before_picture_in_picture_ & ~(WS_MAXIMIZE | WS_MINIMIZE)) |
      WS_THICKFRAME;

  const auto& saved = window_state_.pip;
  const HMONITOR monitor = saved
      ? MonitorFromPoint({saved->left, saved->top}, MONITOR_DEFAULTTONEAREST)
      : MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{sizeof(MONITORINFO)};
  if (!GetMonitorInfo(monitor, &info)) return false;
  const RECT& work = info.rcWork;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;
  if (work_width < 1 || work_height < 1) return false;

  RECT bounds{};
  if (saved) {
    const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
    bounds = window_placement::RestorePictureInPictureBounds(
        *saved, work, picture_in_picture_aspect_ratio_,
        MinimumPictureInPictureWidth(picture_in_picture_aspect_ratio_,
                                     dpi == 0 ? 96 : dpi));
  } else {
    const UINT dpi = GetWindowDpi(window);
    const int margin = std::min(
        ScaleForDpi(16, dpi),
        std::min((work_width - 1) / 2, (work_height - 1) / 2));
    const int max_outer_width =
        std::min(work_width * 2 / 3, work_width - 2 * margin);
    const int max_outer_height =
        std::min(work_height * 2 / 3, work_height - 2 * margin);
    if (max_outer_width < 1 || max_outer_height < 1) return false;
    const auto outer = FitPictureInPictureClientSize(
        ScaleForDpi(420, dpi), picture_in_picture_aspect_ratio_, max_outer_width,
        max_outer_height);
    const LONG right = work.right - margin;
    const LONG bottom = work.bottom - margin;
    bounds = {right - outer.width, bottom - outer.height, right, bottom};
  }

  WINDOWPLACEMENT normal_placement = placement_before_picture_in_picture_;
  normal_placement.showCmd = SW_SHOWNORMAL;

  changing_picture_in_picture_ = true;
  if (!SetWindowPlacement(window, &normal_placement)) {
    changing_picture_in_picture_ = false;
    return false;
  }
  if (!SetWindowLongPtrValue(window, GWL_STYLE, style)) {
    SetWindowPlacement(window, &placement_before_picture_in_picture_);
    changing_picture_in_picture_ = false;
    return false;
  }
  picture_in_picture_ = true;
  const bool positioned = SetWindowPos(
      window, HWND_TOPMOST, bounds.left, bounds.top, bounds.right - bounds.left,
      bounds.bottom - bounds.top, SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
  changing_picture_in_picture_ = false;
  if (!positioned) {
    RestorePictureInPicture(false);
    return false;
  }
  SaveWindowPlacement(window);
  RedrawWindow(window, nullptr, nullptr,
               RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN);
  NotifyPictureInPicture(true, false);
  return true;
}

void FlutterWindow::RestorePictureInPicture(bool save_placement) {
  HWND window = GetHandle();
  if (window == nullptr || !IsWindow(window) || !picture_in_picture_) return;
  if (save_placement) SaveWindowPlacement(window);
  changing_picture_in_picture_ = true;
  picture_in_picture_ = false;
  const LONG_PTR restored_style =
      style_before_picture_in_picture_ & ~(WS_MAXIMIZE | WS_MINIMIZE);
  SetWindowLongPtrValue(window, GWL_STYLE, restored_style);
  SetWindowLongPtrValue(window, GWL_EXSTYLE,
                        ex_style_before_picture_in_picture_);
  UpdateTheme(window);
  SetWindowPlacement(window, &placement_before_picture_in_picture_);
  SetWindowPos(
      window,
      topmost_before_picture_in_picture_ ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0,
      0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED | SWP_NOOWNERZORDER);
  changing_picture_in_picture_ = false;
  RedrawWindow(window, nullptr, nullptr,
               RDW_FRAME | RDW_INVALIDATE | RDW_ALLCHILDREN);
}

void FlutterWindow::SetPictureInPicturePlayer(bool valid, double aspect_ratio) {
  picture_in_picture_player_ = valid;
  double next_aspect_ratio = picture_in_picture_aspect_ratio_;
  if (std::isfinite(aspect_ratio) && aspect_ratio > 0) {
    next_aspect_ratio =
        std::clamp(aspect_ratio, kMinimumPictureInPictureAspectRatio,
                   kMaximumPictureInPictureAspectRatio);
  } else if (aspect_ratio == 0) {
    next_aspect_ratio = kDefaultPictureInPictureAspectRatio;
  }
  if (std::abs(next_aspect_ratio - picture_in_picture_aspect_ratio_) < 0.001) {
    return;
  }
  picture_in_picture_aspect_ratio_ = next_aspect_ratio;
  if (!picture_in_picture_) return;

  HWND window = GetHandle();
  if (window == nullptr || !IsWindow(window)) return;
  RECT bounds{};
  RECT client_bounds{};
  if (!GetWindowRect(window, &bounds) ||
      !GetClientRect(window, &client_bounds)) {
    return;
  }

  const UINT dpi = GetWindowDpi(window);
  PictureInPictureLimits limits{};
  if (!GetPictureInPictureLimits(window, &bounds, next_aspect_ratio, dpi,
                                 &limits)) {
    return;
  }
  const int available_width = limits.work_area.right - limits.work_area.left;
  const int available_height = limits.work_area.bottom - limits.work_area.top;
  const int margin = std::min(
      ScaleForDpi(16, dpi), std::max(0, std::min((available_width - 1) / 2,
                                                 (available_height - 1) / 2)));
  const int max_client_width =
      std::max(1, static_cast<int>(limits.work_area.right -
                                   limits.work_area.left - 2 * margin));
  const int max_client_height =
      std::max(1, static_cast<int>(limits.work_area.bottom -
                                   limits.work_area.top - 2 * margin));
  const PictureInPictureSize outer = FitPictureInPictureClientSize(
      client_bounds.right - client_bounds.left, next_aspect_ratio,
      max_client_width, max_client_height);

  const int min_x = limits.work_area.left + margin;
  const int min_y = limits.work_area.top + margin;
  const int max_x = limits.work_area.right - margin - outer.width;
  const int max_y = limits.work_area.bottom - margin - outer.height;
  const int x = std::clamp(static_cast<int>(bounds.left), min_x, max_x);
  const int y = std::clamp(static_cast<int>(bounds.top), min_y, max_y);
  if (x != bounds.left || y != bounds.top ||
      outer.width != bounds.right - bounds.left ||
      outer.height != bounds.bottom - bounds.top) {
    SetWindowPos(window, nullptr, x, y, outer.width, outer.height,
                 SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER);
  }
}

void FlutterWindow::NotifyPictureInPicture(bool active, bool dismissed) {
  if (picture_in_picture_channel_) {
    picture_in_picture_channel_->InvokeMethod(
        "modeChanged",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
            {flutter::EncodableValue("active"),
             flutter::EncodableValue(active)},
            {flutter::EncodableValue("dismissed"),
             flutter::EncodableValue(dismissed)},
        }));
  }
}

LRESULT CALLBACK FlutterWindow::PictureInPictureChildProc(
    HWND window, UINT message, WPARAM wparam, LPARAM lparam,
    UINT_PTR subclass_id, DWORD_PTR reference) {
  auto* host = reinterpret_cast<FlutterWindow*>(reference);
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, PictureInPictureChildProc, subclass_id);
  } else if (host->picture_in_picture_ && message == WM_NCHITTEST) {
    const LRESULT hit =
        host->MessageHandler(host->GetHandle(), message, wparam, lparam);
    // The Flutter child fills the window. Let the parent receive native edge
    // sizing hits, while every other pixel keeps Flutter's normal input.
    if (hit != HTCLIENT && hit != HTNOWHERE) return HTTRANSPARENT;
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (media_controls_ && media_controls_->HandleMessage(message, wparam, lparam)) {
    return 0;
  }
  if (message == WM_ENTERSIZEMOVE) {
    moving_or_sizing_ = true;
  } else if (message == WM_EXITSIZEMOVE) {
    moving_or_sizing_ = false;
    SaveWindowPlacement(hwnd);
  } else if (message == WM_SIZE && !moving_or_sizing_ && !fullscreen_ &&
             !picture_in_picture_ &&
             (wparam == SIZE_MAXIMIZED || wparam == SIZE_RESTORED)) {
    SaveWindowPlacement(hwnd);
  }
  if (picture_in_picture_ && message == WM_NCCALCSIZE) return 0;
  if (picture_in_picture_ && message == WM_NCHITTEST) {
    RECT bounds{};
    if (GetWindowRect(hwnd, &bounds)) {
      const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (!PtInRect(&bounds, point)) return HTNOWHERE;
      const int edge = ScaleForDpi(6, GetWindowDpi(hwnd));
      const int column = point.x < bounds.left + edge     ? 0
                         : point.x >= bounds.right - edge ? 2
                                                          : 1;
      const int row = point.y < bounds.top + edge       ? 0
                      : point.y >= bounds.bottom - edge ? 2
                                                        : 1;
      constexpr LRESULT hits[3][3] = {{HTTOPLEFT, HTTOP, HTTOPRIGHT},
                                      {HTLEFT, HTCLIENT, HTRIGHT},
                                      {HTBOTTOMLEFT, HTBOTTOM, HTBOTTOMRIGHT}};
      return hits[row][column];
    }
  }

  if (picture_in_picture_ && message == WM_MOVING) {
    if (ClampPictureInPictureBounds(hwnd, picture_in_picture_aspect_ratio_,
                                    reinterpret_cast<RECT*>(lparam))) {
      return TRUE;
    }
  }
  if (picture_in_picture_ && message == WM_WINDOWPOSCHANGING) {
    if (changing_picture_in_picture_) return 0;
    // Let Windows apply track limits before fitting the final placement.
    DefWindowProc(hwnd, message, wparam, lparam);
    auto* position = reinterpret_cast<WINDOWPOS*>(lparam);
    RECT current{};
    if (GetWindowRect(hwnd, &current)) {
      const int x =
          (position->flags & SWP_NOMOVE) != 0 ? current.left : position->x;
      const int y =
          (position->flags & SWP_NOMOVE) != 0 ? current.top : position->y;
      const int width = (position->flags & SWP_NOSIZE) != 0
                            ? current.right - current.left
                            : position->cx;
      const int height = (position->flags & SWP_NOSIZE) != 0
                             ? current.bottom - current.top
                             : position->cy;
      RECT bounds{x, y, x + width, y + height};
      if (ClampPictureInPictureBounds(hwnd, picture_in_picture_aspect_ratio_,
                                      &bounds)) {
        if (bounds.left != x || bounds.top != y) {
          position->flags &= ~SWP_NOMOVE;
          position->x = bounds.left;
          position->y = bounds.top;
        }
        if (bounds.right - bounds.left != width ||
            bounds.bottom - bounds.top != height) {
          position->flags &= ~SWP_NOSIZE;
          position->cx = bounds.right - bounds.left;
          position->cy = bounds.bottom - bounds.top;
        }
      }
    }
    return 0;
  }

  if (message == kStartPictureInPictureDrag) {
    POINT cursor{};
    if (picture_in_picture_ && IsWindow(hwnd) && GetCursorPos(&cursor)) {
      ReleaseCapture();
      if (picture_in_picture_ && IsWindow(hwnd)) {
        SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION,
                    MAKELPARAM(cursor.x, cursor.y));
      }
    }
    return 0;
  }
  if (message == kQuitForAppUpdate) {
    DestroyWindow(hwnd);
    return 0;
  }
  if (picture_in_picture_ && message == WM_CLOSE) {
    RestorePictureInPicture();
    NotifyPictureInPicture(false, true);
    return 0;
  }
  if (picture_in_picture_ && message == WM_DPICHANGED) {
    // Entry has already computed physical bounds for the destination monitor.
    if (changing_picture_in_picture_) return 0;
    const auto* suggested = reinterpret_cast<const RECT*>(lparam);
    const UINT dpi = LOWORD(wparam);
    if (suggested != nullptr && dpi != 0) {
      PictureInPictureLimits limits{};
      if (GetPictureInPictureLimits(hwnd, suggested,
                                    picture_in_picture_aspect_ratio_, dpi,
                                    &limits)) {
        const int available_width =
            static_cast<int>(limits.work_area.right - limits.work_area.left);
        const int available_height =
            static_cast<int>(limits.work_area.bottom - limits.work_area.top);
        const int margin =
            std::min(ScaleForDpi(16, dpi),
                     std::max(0, std::min((available_width - 1) / 2,
                                          (available_height - 1) / 2)));
        const int maximum_client_width =
            std::max(1, available_width - 2 * margin);
        const int maximum_client_height =
            std::max(1, available_height - 2 * margin);
        PictureInPictureSize outer = FitPictureInPictureClientSize(
            std::max(1, static_cast<int>(suggested->right - suggested->left)),
            picture_in_picture_aspect_ratio_, maximum_client_width,
            maximum_client_height);
        if (outer.width < limits.minimum_width) {
          outer = FitPictureInPictureClientSize(
              limits.minimum_width, picture_in_picture_aspect_ratio_,
              maximum_client_width, maximum_client_height);
        }

        const int min_x = static_cast<int>(limits.work_area.left) + margin;
        const int min_y = static_cast<int>(limits.work_area.top) + margin;
        const int max_x =
            static_cast<int>(limits.work_area.right) - margin - outer.width;
        const int max_y =
            static_cast<int>(limits.work_area.bottom) - margin - outer.height;
        const int x =
            std::clamp(static_cast<int>(suggested->left), min_x, max_x);
        const int y =
            std::clamp(static_cast<int>(suggested->top), min_y, max_y);
        SetWindowPos(hwnd, nullptr, x, y, outer.width, outer.height,
                     SWP_NOZORDER | SWP_NOACTIVATE | SWP_NOOWNERZORDER |
                         SWP_FRAMECHANGED);
      }
    }
    return 0;
  }
  if (picture_in_picture_ && message == WM_GETMINMAXINFO) {
    auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
    const UINT dpi = GetWindowDpi(hwnd);
    PictureInPictureLimits limits{};
    if (GetPictureInPictureLimits(
            hwnd, nullptr, picture_in_picture_aspect_ratio_, dpi, &limits)) {
      info->ptMinTrackSize.x = limits.minimum_width;
      info->ptMinTrackSize.y = limits.minimum_height;
      info->ptMaxTrackSize.x = limits.maximum_width;
      info->ptMaxTrackSize.y = limits.maximum_height;
      return 0;
    }
  }
  if (picture_in_picture_ && message == WM_SIZING) {
    auto* rect = reinterpret_cast<RECT*>(lparam);
    const UINT dpi = GetWindowDpi(hwnd);
    PictureInPictureLimits limits{};
    if (GetPictureInPictureLimits(hwnd, rect, picture_in_picture_aspect_ratio_,
                                  dpi, &limits)) {
      const int client_width =
          std::max(1, static_cast<int>(rect->right - rect->left));
      const int client_height =
          std::max(1, static_cast<int>(rect->bottom - rect->top));
      const bool resize_vertical = wparam == WMSZ_TOP || wparam == WMSZ_BOTTOM;
      const int desired_width =
          resize_vertical
              ? static_cast<int>(std::lround(client_height *
                                             picture_in_picture_aspect_ratio_))
              : client_width;
      PictureInPictureSize outer = FitPictureInPictureClientSize(
          desired_width, picture_in_picture_aspect_ratio_, limits.maximum_width,
          limits.maximum_height);
      if (outer.width < limits.minimum_width) {
        outer = {limits.minimum_width, limits.minimum_height};
      }
      const bool resize_left = wparam == WMSZ_LEFT || wparam == WMSZ_TOPLEFT ||
                               wparam == WMSZ_BOTTOMLEFT;
      const bool resize_top = wparam == WMSZ_TOP || wparam == WMSZ_TOPLEFT ||
                              wparam == WMSZ_TOPRIGHT;
      if (resize_left) {
        rect->right =
            std::clamp(rect->right, limits.work_area.left + outer.width,
                       limits.work_area.right);
        rect->left = rect->right - outer.width;
      } else {
        rect->left = std::clamp(rect->left, limits.work_area.left,
                                limits.work_area.right - outer.width);
        rect->right = rect->left + outer.width;
      }
      if (resize_top) {
        rect->bottom =
            std::clamp(rect->bottom, limits.work_area.top + outer.height,
                       limits.work_area.bottom);
        rect->top = rect->bottom - outer.height;
      } else {
        rect->top = std::clamp(rect->top, limits.work_area.top,
                               limits.work_area.bottom - outer.height);
        rect->bottom = rect->top + outer.height;
      }
      return TRUE;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
