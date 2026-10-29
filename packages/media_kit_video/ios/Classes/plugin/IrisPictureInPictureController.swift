// AVSampleBufferDisplayLayer integration adapted from media-kit PR #1410 (MIT).
import AVFoundation
import AVKit
import CoreMedia
import Flutter
import UIKit

@available(iOS 15.0, *)
final class IrisPictureInPictureController: NSObject,
  AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate
{
  private let outputManager: VideoOutputManager
  private let channel: FlutterMethodChannel
  private let hostView: () -> UIView?
  private var controller: AVPictureInPictureController?
  private var displayLayer: AVSampleBufferDisplayLayer?
  private var frameSource: IrisPictureInPictureFrames?
  private var timebase: CMTimebase?
  private var handle: Int64?
  private var possibleObservation: NSKeyValueObservation?
  private var startTimeout: DispatchWorkItem?
  private var pendingStart: FlutterResult?
  private var startIssued = false
  private var hasFrame = false
  private var didStart = false
  private var restoring = false
  private var playing = false
  private var duration = 0.0
  private var rate = 1.0
  private var seekID = 0
  private var seeks: [Int: () -> Void] = [:]

  init(outputManager: VideoOutputManager, messenger: FlutterBinaryMessenger,
       hostView: @escaping () -> UIView?) {
    self.outputManager = outputManager
    self.hostView = hostView
    channel = FlutterMethodChannel(name: "iris/picture_in_picture", binaryMessenger: messenger)
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(false); return }
      self.handleCall(call, result: result)
    }
  }

  private func handleCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    if call.method == "isSupported" {
      result(AVPictureInPictureController.isPictureInPictureSupported())
      return
    }
    if call.method == "attachPlayer" {
      guard let text = args["handle"] as? String, let next = Int64(text) else {
        result(false); return
      }
      result(attach(next))
      return
    }
    guard let expected = args["handle"] as? String,
          expected == handle.map({ String($0) }) else {
      result(call.method == "enter" ? false : nil)
      return
    }
    switch call.method {
    case "setPlayer":
      playing = args["playing"] as? Bool ?? false
      if let aspect = args["aspectRatio"] as? Double, aspect.isFinite, aspect > 0 {
        displayLayer?.frame = CGRect(x: 0, y: 0, width: 2 * aspect, height: 2)
      }
      updateRate()
      controller?.invalidatePlaybackState()
      result(nil)
    case "setPlayback":
      if let milliseconds = (args["position"] as? NSNumber)?.doubleValue, milliseconds.isFinite {
        if let timebase = timebase {
          CMTimebaseSetTime(timebase, time: CMTime(seconds: max(0, milliseconds / 1000), preferredTimescale: 600))
        }
      }
      if let milliseconds = (args["duration"] as? NSNumber)?.doubleValue, milliseconds.isFinite {
        duration = max(0, milliseconds / 1000)
      }
      if let value = args["rate"] as? Double, value.isFinite, value > 0 { rate = value }
      updateRate()
      controller?.invalidatePlaybackState()
      result(nil)
    case "enter":
      enter(result)
    case "seekCompleted":
      if let id = args["id"] as? Int { seeks.removeValue(forKey: id)?() }
      result(nil)
    case "clearPlayer":
      tearDown()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func attach(_ next: Int64) -> Bool {
    if handle == next, controller != nil { return true }
    tearDown()
    guard AVPictureInPictureController.isPictureInPictureSupported(),
          let view = hostView() else { return false }
    // Keep the source in the visible view hierarchy, underneath Flutter.
    let layer = AVSampleBufferDisplayLayer()
    layer.videoGravity = .resizeAspect
    layer.frame = CGRect(x: 0, y: 0, width: 32.0 / 9, height: 2)
    view.layer.insertSublayer(layer, at: 0)
    var clock: CMTimebase?
    guard CMTimebaseCreateWithSourceClock(allocator: kCFAllocatorDefault,
      sourceClock: CMClockGetHostTimeClock(), timebaseOut: &clock) == noErr,
      let clock = clock else {
      layer.removeFromSuperlayer(); return false
    }
    layer.controlTimebase = clock
    timebase = clock
    let source = AVPictureInPictureController.ContentSource(
      sampleBufferDisplayLayer: layer, playbackDelegate: self)
    let pip = AVPictureInPictureController(contentSource: source)
    pip.delegate = self
    // Entry is explicit, so app backgrounding cannot race the player's pause policy.
    pip.canStartPictureInPictureAutomaticallyFromInline = false
    displayLayer = layer
    controller = pip
    handle = next
    possibleObservation = pip.observe(\.isPictureInPicturePossible, options: [.new]) {
      [weak self] _, _ in
      DispatchQueue.main.async { self?.tryStart() }
    }
    return true
  }

  private func updateRate() {
    if let timebase = timebase { CMTimebaseSetRate(timebase, rate: playing ? rate : 0) }
  }

  private func enter(_ result: @escaping FlutterResult) {
    guard let pip = controller, let handle = handle, let layer = displayLayer else {
      result(false); return
    }
    if pip.isPictureInPictureActive { result(true); return }
    guard pendingStart == nil else { result(false); return }
    do {
      let audio = AVAudioSession.sharedInstance()
      try audio.setCategory(.playback, mode: .moviePlayback)
      try audio.setActive(true)
    } catch {
      result(FlutterError(code: "pip_audio_session", message: error.localizedDescription, details: nil))
      return
    }
    restoring = false
    didStart = false
    startIssued = false
    pendingStart = result
    let frames = IrisPictureInPictureFrames { [weak self, weak layer] pixelBuffer in
      guard let self = self, self.handle == handle, let layer = layer,
            self.displayLayer === layer else { return }
      self.enqueue(pixelBuffer, into: layer)
    }
    frameSource = frames
    guard outputManager.setFrameHandler(handle: handle, { [weak frames] frame in
      frames?.receive(frame)
    }) else {
      finishStart(false)
      stopFrames()
      return
    }
    let timeout = DispatchWorkItem { [weak self] in
      guard let self = self, self.pendingStart != nil else { return }
      self.emitMode(active: false)
      self.tearDown()
    }
    startTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
    tryStart()
  }

  private func enqueue(_ frame: CVPixelBuffer, into layer: AVSampleBufferDisplayLayer) {
    if layer.status == .failed { layer.flush() }
    guard layer.isReadyForMoreMediaData else { return }
    var description: CMVideoFormatDescription?
    guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
      imageBuffer: frame, formatDescriptionOut: &description) == noErr,
      let description = description else { return }
    var timing = CMSampleTimingInfo(duration: .invalid,
      presentationTimeStamp: timebase.map { CMTimebaseGetTime($0) } ?? .zero, decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    guard CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
      imageBuffer: frame, formatDescription: description, sampleTiming: &timing,
      sampleBufferOut: &sample) == noErr, let sample = sample else { return }
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: true)
      as? [NSMutableDictionary], let first = attachments.first {
      first[kCMSampleAttachmentKey_DisplayImmediately as NSString] = true
    }
    layer.enqueue(sample)
    hasFrame = true
    tryStart()
  }

  private func tryStart() {
    guard pendingStart != nil, hasFrame, !startIssued, let pip = controller,
          pip.isPictureInPicturePossible else { return }
    startIssued = true
    pip.startPictureInPicture()
  }

  private func finishStart(_ success: Bool) {
    startTimeout?.cancel()
    startTimeout = nil
    let callback = pendingStart
    pendingStart = nil
    callback?(success)
  }

  private func emit(_ event: String, _ values: [String: Any] = [:]) {
    guard let handle = handle else { return }
    var arguments = values
    arguments["handle"] = String(handle)
    channel.invokeMethod(event, arguments: arguments)
  }

  private func emitMode(active: Bool, dismissed: Bool = false) {
    emit("modeChanged", ["active": active, "dismissed": dismissed])
  }

  private func stopFrames() {
    hasFrame = false
    frameSource?.invalidate()
    frameSource = nil
    if let handle = handle { _ = outputManager.setFrameHandler(handle: handle, nil) }
    displayLayer?.flushAndRemoveImage()
  }

  private func tearDown() {
    finishStart(false)
    possibleObservation?.invalidate()
    possibleObservation = nil
    controller?.delegate = nil
    controller?.stopPictureInPicture()
    stopFrames()
    let completions = Array(seeks.values)
    seeks.removeAll()
    for completion in completions { completion() }
    displayLayer?.removeFromSuperlayer()
    controller = nil
    displayLayer = nil
    timebase = nil
    handle = nil
    playing = false
    duration = 0
    rate = 1
    didStart = false
  }

  func disposeOutput(handle: Int64) {
    guard self.handle == handle else { return }
    emitMode(active: false)
    tearDown()
  }

  func pictureInPictureControllerWillStartPictureInPicture(_ pip: AVPictureInPictureController) {
    guard pip === controller else { return }
    emitMode(active: true)
  }

  func pictureInPictureControllerDidStartPictureInPicture(_ pip: AVPictureInPictureController) {
    guard pip === controller else { return }
    didStart = true
    finishStart(true)
    emitMode(active: true)
  }

  func pictureInPictureController(_ pip: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error) {
    guard pip === controller else { return }
    finishStart(false)
    stopFrames()
    emitMode(active: false)
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ pip: AVPictureInPictureController) {
    guard pip === controller else { return }
    finishStart(false)
    stopFrames()
    emitMode(active: false, dismissed: didStart && !restoring)
    didStart = false
    restoring = false
  }

  func pictureInPictureController(_ pip: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    guard pip === controller else { completionHandler(false); return }
    restoring = true
    // Iris keeps the existing player route and decoder alive throughout PiP.
    completionHandler(true)
  }

  func pictureInPictureController(_ pip: AVPictureInPictureController, setPlaying playing: Bool) {
    guard pip === controller else { return }
    emit("setPlaying", ["playing": playing])
  }

  func pictureInPictureControllerTimeRangeForPlayback(_ pip: AVPictureInPictureController) -> CMTimeRange {
    CMTimeRange(start: .zero, duration: duration > 0
      ? CMTime(seconds: duration, preferredTimescale: 600) : .positiveInfinity)
  }

  func pictureInPictureControllerIsPlaybackPaused(_ pip: AVPictureInPictureController) -> Bool { !playing }

  func pictureInPictureController(_ pip: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

  func pictureInPictureController(_ pip: AVPictureInPictureController, skipByInterval interval: CMTime,
    completion completionHandler: @escaping () -> Void) {
    guard pip === controller, interval.seconds.isFinite else { completionHandler(); return }
    seekID += 1
    let id = seekID
    seeks[id] = completionHandler
    emit("seek", ["id": id, "milliseconds": Int((interval.seconds * 1000).rounded())])
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
      self?.seeks.removeValue(forKey: id)?()
    }
  }
}

/// mpv reuses its render surfaces. Copy into a bounded pool before AVKit retains
/// a frame asynchronously; the callback queue keeps only one pending frame.
private final class IrisPictureInPictureFrames {
  private let lock = NSLock()
  private var pending = false
  private var valid = true
  private var pool: CVPixelBufferPool?
  private var width = 0
  private var height = 0
  private var pixelFormat: OSType = 0
  private let output: (CVPixelBuffer) -> Void

  init(output: @escaping (CVPixelBuffer) -> Void) { self.output = output }

  func invalidate() {
    lock.lock()
    valid = false
    lock.unlock()
  }

  func receive(_ source: CVPixelBuffer) {
    lock.lock()
    defer { lock.unlock() }
    guard valid, !pending else { return }
    let w = CVPixelBufferGetWidth(source)
    let h = CVPixelBufferGetHeight(source)
    let format = CVPixelBufferGetPixelFormatType(source)
    guard !CVPixelBufferIsPlanar(source) else { return }
    if pool == nil || w != width || h != height || format != pixelFormat {
      let attributes: [String: Any] = [
        kCVPixelBufferWidthKey as String: w, kCVPixelBufferHeightKey as String: h,
        kCVPixelBufferPixelFormatTypeKey as String: format,
        kCVPixelBufferIOSurfacePropertiesKey as String: [:],
      ]
      guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attributes as CFDictionary, &pool) == kCVReturnSuccess else { return }
      width = w; height = h; pixelFormat = format
    }
    guard let pool = pool else { return }
    var copy: CVPixelBuffer?
    let limits = [kCVPixelBufferPoolAllocationThresholdKey as String: 3] as CFDictionary
    guard CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, limits, &copy) == kCVReturnSuccess,
      let copy = copy else { return }
    guard CVPixelBufferLockBaseAddress(source, .readOnly) == kCVReturnSuccess else { return }
    defer { CVPixelBufferUnlockBaseAddress(source, .readOnly) }
    guard CVPixelBufferLockBaseAddress(copy, []) == kCVReturnSuccess else { return }
    defer { CVPixelBufferUnlockBaseAddress(copy, []) }
    guard let from = CVPixelBufferGetBaseAddress(source), let to = CVPixelBufferGetBaseAddress(copy) else { return }
    let fromStride = CVPixelBufferGetBytesPerRow(source)
    let toStride = CVPixelBufferGetBytesPerRow(copy)
    for row in 0..<h { memcpy(to.advanced(by: row * toStride), from.advanced(by: row * fromStride), min(fromStride, toStride)) }
    pending = true
    DispatchQueue.main.async { [weak self] in
      guard let self = self else { return }
      self.lock.lock()
      let valid = self.valid
      self.pending = false
      self.lock.unlock()
      if valid { self.output(copy) }
    }
  }
}
