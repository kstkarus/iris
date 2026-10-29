#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public protocol ResizableTextureProtocol: NSObject, FlutterTexture {
  var onFrameRendered: ((CVPixelBuffer) -> Void)? { get set }
  func resize(_ size: CGSize)
  func render(_ size: CGSize)
  func dispose()
}
