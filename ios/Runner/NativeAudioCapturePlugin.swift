import Flutter

class NativeAudioCapturePlugin: NSObject, FlutterPlugin {
    private var capture: NativeAudioCapture?
    private var pcmChannel: FlutterBasicMessageChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeAudioCapturePlugin()

        let controlChannel = FlutterMethodChannel(
            name: "spacenotes/native_audio_control",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: controlChannel)

        instance.pcmChannel = FlutterBasicMessageChannel(
            name: "spacenotes/native_audio",
            binaryMessenger: registrar.messenger(),
            codec: FlutterBinaryCodec.sharedInstance()
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            capture?.stop()
            capture = NativeAudioCapture()
            capture?.start { [weak self] pcmData in
                guard let channel = self?.pcmChannel else { return }
                DispatchQueue.main.async {
                    channel.sendMessage(pcmData)
                }
            }
            result(nil)

        case "stop":
            capture?.stop()
            capture = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
