#include "player_media_controls.h"

#include <flutter/standard_method_codec.h>
#include <roapi.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <iterator>
#include <type_traits>

namespace {
namespace media = winrt::Windows::Media;
using flutter::EncodableMap;
using flutter::EncodableValue;
using Milliseconds = std::chrono::milliseconds;

// SMTC callbacks run off the window thread. The message carries the session
// ID so an already queued command cannot affect the next episode.
enum RemoteMessage : UINT {
  kPlay = WM_APP + 10,
  kPause,
  kNext,
  kSeekForward,
  kSeekBackward,
  kSeekTo,
};
constexpr const char* kMethods[] = {"play",        "pause",        "next",
                                    "seekForward", "seekBackward", "seekTo"};
static_assert(std::size(kMethods) == kSeekTo - kPlay + 1);

template <typename T>
T Read(const EncodableMap& arguments, const char* key, T fallback = T{}) {
  const auto entry = arguments.find(EncodableValue(key));
  if (entry != arguments.end()) {
    if (const auto* value = std::get_if<T>(&entry->second)) return *value;
    if constexpr (std::is_same_v<T, int64_t>) {
      if (const auto* value = std::get_if<int32_t>(&entry->second))
        return *value;
    }
  }
  return fallback;
}
}  // namespace

PlayerMediaControls::PlayerMediaControls(HWND window,
                                         flutter::BinaryMessenger* messenger)
    : window_(window),
      channel_(messenger, "iris/player_media_controls",
               &flutter::StandardMethodCodec::GetInstance()),
      winrt_initialized_(SUCCEEDED(RoInitialize(RO_INIT_SINGLETHREADED))) {
  channel_.SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "update" && call.method_name() != "deactivate") {
      result->NotImplemented();
      return;
    }
    const auto* arguments = call.arguments()
                                ? std::get_if<EncodableMap>(call.arguments())
                                : nullptr;
    const auto session = arguments ? Read<int64_t>(*arguments, "session") : 0;
    if (session <= 0) {
      result->Error("invalid_session", "Expected a player session ID.");
      return;
    }
    if (call.method_name() == "deactivate") {
      if (session == session_) Deactivate();
    } else if (winrt_initialized_) {
      try {
        if (session != session_) Activate(session);
        Update(*arguments);
      } catch (const winrt::hresult_error&) {
        Deactivate();
        result->Error("media_controls_unavailable",
                      "Windows media controls could not be updated.");
        return;
      }
    }
    result->Success();
  });
}

PlayerMediaControls::~PlayerMediaControls() {
  channel_.SetMethodCallHandler(nullptr);
  Deactivate();
  if (winrt_initialized_) RoUninitialize();
}

void PlayerMediaControls::Activate(int64_t session) {
  Deactivate();
  const auto factory =
      winrt::get_activation_factory<media::SystemMediaTransportControls,
                                    ISystemMediaTransportControlsInterop>();
  winrt::check_hresult(factory->GetForWindow(
      window_, winrt::guid_of<media::ISystemMediaTransportControls>(),
      winrt::put_abi(controls_)));
  session_ = session;
  button_pressed_ = controls_.ButtonPressed(
      [window = window_, session](const auto&, const auto& args) {
        UINT message;
        switch (args.Button()) {
          case media::SystemMediaTransportControlsButton::Play:
            message = kPlay;
            break;
          case media::SystemMediaTransportControlsButton::Pause:
            message = kPause;
            break;
          case media::SystemMediaTransportControlsButton::Next:
            message = kNext;
            break;
          case media::SystemMediaTransportControlsButton::FastForward:
            message = kSeekForward;
            break;
          case media::SystemMediaTransportControlsButton::Rewind:
            message = kSeekBackward;
            break;
          default:
            return;
        }
        PostMessage(window, message, static_cast<WPARAM>(session), 0);
      });
  position_requested_ = controls_.PlaybackPositionChangeRequested(
      [window = window_, session](const auto&, const auto& args) {
        const auto position = std::chrono::duration_cast<Milliseconds>(
            args.RequestedPlaybackPosition());
        PostMessage(window, kSeekTo, static_cast<WPARAM>(session),
                    static_cast<LPARAM>(position.count()));
      });
  controls_.IsPlayEnabled(true);
  controls_.IsPauseEnabled(true);
}

void PlayerMediaControls::Update(const EncodableMap& arguments) {
  const auto duration = Milliseconds(
      std::max<int64_t>(0, Read<int64_t>(arguments, "durationMs")));
  const auto position = Milliseconds(Read<int64_t>(arguments, "positionMs"));
  const auto playing = Read<bool>(arguments, "playing");
  const auto buffering = Read<bool>(arguments, "buffering");
  const auto rate = Read<double>(arguments, "rate", 1.0);

  auto updater = controls_.DisplayUpdater();
  updater.Type(media::MediaPlaybackType::Video);
  const auto video = updater.VideoProperties();
  video.Title(winrt::to_hstring(Read<std::string>(arguments, "title")));
  video.Subtitle(winrt::to_hstring(Read<std::string>(arguments, "episode")));
  updater.Update();

  controls_.IsNextEnabled(Read<bool>(arguments, "canNext"));
  controls_.IsFastForwardEnabled(duration.count() > 0);
  controls_.IsRewindEnabled(duration.count() > 0);
  if (std::isfinite(rate) && rate > 0) controls_.PlaybackRate(rate);
  media::SystemMediaTransportControlsTimelineProperties timeline;
  timeline.StartTime({});
  timeline.MinSeekTime({});
  timeline.EndTime(duration);
  timeline.MaxSeekTime(duration);
  timeline.Position(std::clamp(position, Milliseconds::zero(), duration));
  controls_.UpdateTimelineProperties(timeline);
  controls_.PlaybackStatus(playing ? (buffering
                                          ? media::MediaPlaybackStatus::Changing
                                          : media::MediaPlaybackStatus::Playing)
                                   : media::MediaPlaybackStatus::Paused);
  controls_.IsEnabled(true);
}

void PlayerMediaControls::Deactivate() noexcept {
  session_ = 0;
  if (!controls_) return;
  if (button_pressed_) controls_.ButtonPressed(*button_pressed_);
  if (position_requested_)
    controls_.PlaybackPositionChangeRequested(*position_requested_);
  button_pressed_.reset();
  position_requested_.reset();
  try {
    controls_.IsEnabled(false);
    controls_.PlaybackStatus(media::MediaPlaybackStatus::Closed);
    auto updater = controls_.DisplayUpdater();
    updater.ClearAll();
    updater.Update();
  } catch (const winrt::hresult_error&) {
    // The media service can disappear before the window does.
  }
  controls_ = nullptr;
}

bool PlayerMediaControls::HandleMessage(UINT message, WPARAM session,
                                        LPARAM position_ms) {
  if (message < kPlay || message > kSeekTo) return false;
  if (session_ == 0 || static_cast<WPARAM>(session_) != session) return true;
  EncodableMap arguments{{EncodableValue("session"), EncodableValue(session_)}};
  if (message == kSeekTo) {
    arguments[EncodableValue("positionMs")] =
        EncodableValue(static_cast<int64_t>(position_ms));
  }
  channel_.InvokeMethod(kMethods[message - kPlay],
                        std::make_unique<EncodableValue>(std::move(arguments)));
  return true;
}
