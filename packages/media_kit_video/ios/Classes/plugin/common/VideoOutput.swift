#if canImport(Flutter)
  import Flutter
  import UIKit
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// This class creates and manipulates the different types of FlutterTexture,
// handles resizing, rendering calls, and notify Flutter when a new frame is
// available to render.
//
// To improve the user experience, a worker is used to execute heavy tasks on a
// dedicated thread.
public class VideoOutput: NSObject {
  // Will be called on the main thread
  public typealias TextureUpdateCallback = (Int64, CGSize) -> Void

  private static let isSimulator: Bool = {
    let isSim: Bool
    #if targetEnvironment(simulator)
      isSim = true
    #else
      isSim = false
    #endif
    return isSim
  }()

  private let handle: OpaquePointer
  private let enableHardwareAcceleration: Bool
  private let registry: FlutterTextureRegistry
  private let textureUpdateCallback: TextureUpdateCallback
  private let worker: Worker = .init()
  private var width: Int64?
  private var height: Int64?
  private var texture: ResizableTextureProtocol!
  private var textureId: Int64 = -1
  private var currentSize: CGSize = CGSize.zero
  private var disposed: Bool = false
  private var usingHardwareAcceleration = false
  private var foregroundObserver: NSObjectProtocol?

  init(
    handle: Int64,
    configuration: VideoOutputConfiguration,
    registry: FlutterTextureRegistry,
    textureUpdateCallback: @escaping TextureUpdateCallback
  ) {
    let handle = OpaquePointer(bitPattern: Int(handle))
    assert(handle != nil, "handle casting")

    self.handle = handle!
    width = configuration.width
    height = configuration.height
    enableHardwareAcceleration = configuration.enableHardwareAcceleration
    self.registry = registry
    self.textureUpdateCallback = textureUpdateCallback

    super.init()

    foregroundObserver = NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
    ) { [weak self] _ in
      self?.worker.enqueue { [weak self] in
        guard let self = self, self.texture?.onFrameRendered == nil else { return }
        self.switchRendering(allowHardwareAcceleration: true)
      }
    }

    worker.enqueue {
      self._init()
    }
  }

  deinit {
    if let observer = foregroundObserver { NotificationCenter.default.removeObserver(observer) }
    worker.cancel()

    disposed = true
    disposeTextureId()
  }

  public func setSize(width: Int64?, height: Int64?) {
    worker.enqueue {
      self.width = width
      self.height = height
    }
  }

  public func dispose(completion: @escaping () -> Void) {
    worker.enqueue {
      self.disposed = true
      self.texture?.onFrameRendered = nil
      self.texture?.dispose()
      self.texture = nil
      self.disposeTextureId()
      self.worker.cancel()
      // Dart may free mpv only after the rendering worker has let it go.
      DispatchQueue.main.async { completion() }
    }
  }

  public func setFrameHandler(_ callback: ((CVPixelBuffer) -> Void)?) {
    let restoreHardware = callback == nil && UIApplication.shared.applicationState == .active
    worker.enqueue {
      // OpenGL ES cannot submit frames while iOS backgrounds the app.
      // Use the existing software output for the whole PiP session.
      self.switchRendering(allowHardwareAcceleration: restoreHardware)
      self.texture.onFrameRendered = callback
      // A paused video still needs its first PiP frame.
      if let frame = self.texture.copyPixelBuffer()?.takeRetainedValue() {
        callback?(frame)
      }
    }
  }

  private func switchRendering(allowHardwareAcceleration: Bool) {
    let hardware = !VideoOutput.isSimulator && enableHardwareAcceleration && allowHardwareAcceleration
    guard !disposed, texture != nil, hardware != usingHardwareAcceleration else { return }
    let callback = texture.onFrameRendered
    let videoTrack = mpv_get_property_string(handle, "vid")
    defer { if let videoTrack = videoTrack { mpv_free(videoTrack) } }
    mpv_set_property_string(handle, "vid", "no")
    texture.dispose()
    disposeTextureId()
    texture = nil
    currentSize = .zero
    _init(allowHardwareAcceleration: allowHardwareAcceleration)
    texture.onFrameRendered = callback
    if let videoTrack = videoTrack { mpv_set_property_string(handle, "vid", videoTrack) }
  }

  private func _init(allowHardwareAcceleration: Bool = true) {
    let enableHardwareAcceleration =
      !VideoOutput.isSimulator && self.enableHardwareAcceleration && allowHardwareAcceleration
    usingHardwareAcceleration = enableHardwareAcceleration

    NSLog(
      "VideoOutput: enableHardwareAcceleration: \(enableHardwareAcceleration)"
    )

    if VideoOutput.isSimulator {
      NSLog(
        "VideoOutput: warning: hardware rendering is disabled in the iOS simulator, due to an incompatibility with OpenGL ES"
      )
    }

    if enableHardwareAcceleration {
      texture = SafeResizableTexture(
        TextureHW(
          handle: handle,
          // Use `weak self` to prevent memory leaks
          updateCallback: { [weak self]() in
            guard let that = self else {
              return
            }
            that.updateCallback()
          }
        )
      )
    } else {
      texture = SafeResizableTexture(
        TextureSW(
          handle: handle,
          // Use `weak self` to prevent memory leaks
          updateCallback: { [weak self]() in
            guard let that = self else {
              return
            }
            that.updateCallback()
          }
        )
      )
    }

    DispatchQueue.main.sync { [weak self]() in
      guard let that = self else {
        return
      }
      that.registerTextureId()
    }
  }

  // Must be run on the main thread
  private func registerTextureId() {
    // Textures must be registered on the platform thread.
    textureId = registry.register(texture)
    // textureUpdateCallback must run on the main thread
    textureUpdateCallback(textureId, CGSize(width: 0, height: 0))
  }

  private func disposeTextureId() {
    guard textureId >= 0 else { return }
    let registry_ = self.registry
    let textureId_ = self.textureId
    textureId = -1
    DispatchQueue.main.async {
      // Textures must be unregistered on the platform thread
      registry_.unregisterTexture(textureId_)
    }
  }

  public func updateCallback() {
    worker.enqueue {
      self._updateCallback()
    }
  }

  private func _updateCallback() {
    let size = videoSize

    if size.width == 0 || size.height == 0 {
      return
    }

    if currentSize != size {
      currentSize = size

      texture.resize(size)
      DispatchQueue.main.sync { [weak self] in
        guard let that = self else { return }
        // textureUpdateCallback must run on the main thread
        that.textureUpdateCallback(that.textureId, size)
      }
    }

    if disposed {
      return
    }

    texture.render(size)
    DispatchQueue.main.sync { [weak self] in
      guard let that = self else { return }
      // Textures must be marked as available from the main thread
      that.registry.textureFrameAvailable(that.textureId)
    }
  }

    private var videoSize: CGSize {
        // fixed size
        if width != nil && height != nil {
            return CGSize(
                width: Double(width!),
                height: Double(height!)
            )
        }
        
        let params = MPVHelpers.getVideoOutParams(handle)
        return CGSize(
            width: Double(width ?? (params.rotate == 0 || params.rotate == 180
                                    ? params.dw
                                    : params.dh)),
            height: Double(height ?? (params.rotate == 0 || params.rotate == 180
                                      ? params.dh
                                      : params.dw))
        )
  }
}
