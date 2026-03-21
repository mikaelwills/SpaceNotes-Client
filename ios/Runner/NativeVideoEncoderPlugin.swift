import Flutter

class NativeVideoEncoderPlugin: NSObject, FlutterPlugin, FlutterApplicationLifeCycleDelegate {
    private var encoder: NativeVideoEncoder?
    private var frameChannel: FlutterBasicMessageChannel?
    private weak var textureRegistry: FlutterTextureRegistry?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeVideoEncoderPlugin()
        instance.textureRegistry = registrar.textures()
        registrar.addApplicationDelegate(instance)

        let controlChannel = FlutterMethodChannel(
            name: "spacenotes/native_video_control",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: controlChannel)

        instance.frameChannel = FlutterBasicMessageChannel(
            name: "spacenotes/native_video",
            binaryMessenger: registrar.messenger(),
            codec: FlutterBinaryCodec.sharedInstance()
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            guard let args = call.arguments as? [String: Any] else {
                result(FlutterError(code: "ARGS", message: "Invalid arguments", details: nil))
                return
            }
            let fps = args["fps"] as? Int ?? 30
            let width = args["width"] as? Int ?? 1920
            let height = args["height"] as? Int ?? 1080
            let quality = args["quality"] as? Double ?? 0.8
            let codec = args["codec"] as? String ?? "jpeg"

            encoder?.stop()
            encoder = NativeVideoEncoder()
            encoder?.start(fps: fps, width: width, height: height, quality: quality, codec: codec, textureRegistry: textureRegistry) { [weak self] frame in
                guard let channel = self?.frameChannel else { return }

                var header = Data(count: 10)
                var micros = frame.encodeMicros.littleEndian
                var size = UInt32(frame.data.count).littleEndian
                header[0] = frame.codec
                header[1] = frame.isKeyframe ? 1 : 0
                header.replaceSubrange(2..<6, with: Data(bytes: &micros, count: 4))
                header.replaceSubrange(6..<10, with: Data(bytes: &size, count: 4))

                var payload = header
                payload.append(frame.data)

                DispatchQueue.main.async {
                    channel.sendMessage(payload)
                }
            }

            let textureId = encoder?.textureId ?? -1
            result(NSNumber(value: textureId))

        case "switchCamera":
            encoder?.switchCamera()
            let textureId = encoder?.textureId ?? -1
            result(NSNumber(value: textureId))

        case "stop":
            encoder?.stop()
            encoder = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        encoder?.stop()
        encoder = nil
    }

    func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        encoder?.stop()
        encoder = nil
    }
}
