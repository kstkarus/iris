#ifndef RUNNER_PLAYER_MEDIA_CONTROLS_H_
#define RUNNER_PLAYER_MEDIA_CONTROLS_H_

#include <windows.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <winrt/Windows.Media.h>

#include <cstdint>
#include <optional>

class PlayerMediaControls {
 public:
  PlayerMediaControls(HWND window, flutter::BinaryMessenger* messenger);
  ~PlayerMediaControls();

  bool HandleMessage(UINT message, WPARAM session, LPARAM position_ms);

 private:
  void Activate(int64_t session);
  void Update(const flutter::EncodableMap& arguments);
  void Deactivate() noexcept;

  const HWND window_;
  flutter::MethodChannel<flutter::EncodableValue> channel_;
  const bool winrt_initialized_;
  int64_t session_ = 0;
  winrt::Windows::Media::SystemMediaTransportControls controls_{nullptr};
  std::optional<winrt::event_token> button_pressed_;
  std::optional<winrt::event_token> position_requested_;
};

#endif  // RUNNER_PLAYER_MEDIA_CONTROLS_H_
