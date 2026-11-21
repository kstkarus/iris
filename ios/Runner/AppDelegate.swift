import AVFoundation
import Flutter
import MediaPlayer
import UIKit
import MachO

private let playerRuntimeStatsChannelName = "iris/player_runtime_stats"

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var playerMediaControls: PlayerMediaControls?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    excludeTransientDirectoriesFromBackup()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    playerMediaControls = nil
    playerMediaControls = PlayerMediaControls(messenger: messenger)

    let channel = FlutterMethodChannel(
      name: playerRuntimeStatsChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getAppMemoryBytes":
        result(self.readAppMemoryBytes())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func excludeTransientDirectoriesFromBackup() {
    let fileManager = FileManager.default
    guard let supportDirectory = try? fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ) else {
      return
    }
    for name in ["offline_downloads", "app_updates"] {
      var directory = supportDirectory.appendingPathComponent(name, isDirectory: true)
      try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      try? directory.setResourceValues(values)
    }
  }

  private func readAppMemoryBytes() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

    let status = withUnsafeMutablePointer(to: &info) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
        task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &count)
      }
    }

    guard status == KERN_SUCCESS else {
      return 0
    }

    return Int64(info.resident_size)
  }
}

private final class PlayerMediaControls {
  private let channel: FlutterMethodChannel
  private let commandCenter = MPRemoteCommandCenter.shared()
  private var session: Int64?
  private var targets: [(MPRemoteCommand, Any)] = []
  private var observers: [NSObjectProtocol] = []

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "iris/player_media_controls", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(nil); return }
      guard call.method == "update" || call.method == "deactivate" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let id = (arguments["session"] as? NSNumber)?.int64Value, id > 0 else {
        result(FlutterError(code: "invalid_session", message: "Expected a player session ID.", details: nil))
        return
      }
      if call.method == "deactivate" {
        if self.session == id { self.deactivate() }
      } else {
        if self.session != id { self.activate(id) }
        self.update(arguments)
      }
      result(nil)
    }
  }

  deinit {
    channel.setMethodCallHandler(nil)
    deactivate()
  }

  private func activate(_ id: Int64) {
    deactivate()
    session = id
    let commands = commandCenter
    commands.skipForwardCommand.preferredIntervals = [10]
    commands.skipBackwardCommand.preferredIntervals = [10]
    for (command, method) in [
      (commands.playCommand, "play"),
      (commands.pauseCommand, "pause"),
      (commands.togglePlayPauseCommand, "togglePlayPause"),
      (commands.nextTrackCommand, "next"),
      (commands.skipForwardCommand, "seekForward"),
      (commands.skipBackwardCommand, "seekBackward"),
      (commands.changePlaybackPositionCommand, "seekTo"),
    ] as [(MPRemoteCommand, String)] {
      let target = command.addTarget { [weak self] event in
        if method == "seekTo" {
          guard let seek = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
          let milliseconds = seek.positionTime * 1000
          guard milliseconds.isFinite, milliseconds >= 0, milliseconds < Double(Int64.max) else {
            return .commandFailed
          }
          self?.send(method, session: id, position: Int64(milliseconds.rounded(.down)))
        } else {
          self?.send(method, session: id)
        }
        return .success
      }
      targets.append((command, target))
    }

    let center = NotificationCenter.default
    // Observe the output chosen by mpv and AVKit's PiP session.
    let audio = AVAudioSession.sharedInstance()
    observers = [
      center.addObserver(forName: AVAudioSession.routeChangeNotification, object: audio, queue: .main) {
        [weak self] notification in
        let reason = (notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? NSNumber)?.uintValue
        if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue {
          self?.send("pause", session: id)
        }
      },
      center.addObserver(forName: AVAudioSession.interruptionNotification, object: audio, queue: .main) {
        [weak self] notification in
        let type = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? NSNumber)?.uintValue
        if type == AVAudioSession.InterruptionType.began.rawValue {
          self?.send("pause", session: id)
        }
      },
    ]
  }

  private func update(_ arguments: [String: Any]) {
    let duration = (arguments["durationMs"] as? NSNumber)?.doubleValue ?? 0
    let position = (arguments["positionMs"] as? NSNumber)?.doubleValue ?? 0
    let rate = (arguments["rate"] as? NSNumber)?.doubleValue ?? 1
    let advancing = arguments["playing"] as? Bool == true && arguments["buffering"] as? Bool != true
    let canSeek = duration > 0
    let commands = commandCenter
    commands.playCommand.isEnabled = true
    commands.pauseCommand.isEnabled = true
    commands.togglePlayPauseCommand.isEnabled = true
    commands.nextTrackCommand.isEnabled = arguments["canNext"] as? Bool == true
    commands.skipForwardCommand.isEnabled = canSeek
    commands.skipBackwardCommand.isEnabled = canSeek
    commands.changePlaybackPositionCommand.isEnabled = canSeek

    var info: [String: Any] = [
      MPMediaItemPropertyTitle: arguments["title"] as? String ?? "",
      MPMediaItemPropertyArtist: arguments["episode"] as? String ?? "",
      MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.video.rawValue,
      MPNowPlayingInfoPropertyElapsedPlaybackTime: position / 1000,
      MPNowPlayingInfoPropertyPlaybackRate: advancing ? rate : 0,
    ]
    if canSeek { info[MPMediaItemPropertyPlaybackDuration] = duration / 1000 }
    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
  }

  private func send(_ method: String, session: Int64, position: Int64? = nil) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.session == session else { return }
      var arguments: [String: Any] = ["session": session]
      if let position { arguments["positionMs"] = position }
      self.channel.invokeMethod(method, arguments: arguments)
    }
  }

  private func deactivate() {
    guard session != nil else { return }
    session = nil
    for (command, target) in targets {
      command.removeTarget(target)
      command.isEnabled = false
    }
    targets.removeAll()
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    observers.removeAll()
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }
}
