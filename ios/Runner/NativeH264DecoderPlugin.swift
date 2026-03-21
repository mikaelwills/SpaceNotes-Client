import Flutter

class NativeH264DecoderPlugin: NSObject, FlutterPlugin {
    private var decoder: NativeH264Decoder?
    private var frameChannel: FlutterBasicMessageChannel?
    private weak var textureRegistry: FlutterTextureRegistry?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeH264DecoderPlugin()
        instance.textureRegistry = registrar.textures()

        let controlChannel = FlutterMethodChannel(
            name: "spacenotes/h264_decoder_control",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: controlChannel)

        instance.frameChannel = FlutterBasicMessageChannel(
            name: "spacenotes/h264_decoder_frame",
            binaryMessenger: registrar.messenger(),
            codec: FlutterBinaryCodec.sharedInstance()
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            decoder?.stop()
            decoder = NativeH264Decoder()
            decoder?.setup(textureRegistry: textureRegistry)

            frameChannel?.setMessageHandler { [weak self] message, reply in
                guard let data = message as? Data, data.count > 5, let decoder = self?.decoder else {
                    reply(nil)
                    return
                }

                let seq = Int(data[0]) | (Int(data[1]) << 8) | (Int(data[2]) << 16) | (Int(data[3]) << 24)
                let isKeyframe = data[4] == 1
                let h264Data = data.subdata(in: 5..<data.count)

                decoder.decodeFrame(data: h264Data, seq: seq, isKeyframe: isKeyframe)
                reply(nil)
            }

            let textureId = decoder?.textureId ?? -1
            result(NSNumber(value: textureId))

        case "stop":
            frameChannel?.setMessageHandler(nil)
            decoder?.stop()
            decoder = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
