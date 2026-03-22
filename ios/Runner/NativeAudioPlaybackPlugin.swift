import Flutter

class NativeAudioPlaybackPlugin: NSObject, FlutterPlugin {
    private var playback: NativeAudioPlayback?
    private var pcmChannel: FlutterBasicMessageChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NativeAudioPlaybackPlugin()

        let controlChannel = FlutterMethodChannel(
            name: "spacenotes/native_audio_playback_control",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: controlChannel)

        instance.pcmChannel = FlutterBasicMessageChannel(
            name: "spacenotes/native_audio_playback",
            binaryMessenger: registrar.messenger(),
            codec: FlutterBinaryCodec.sharedInstance()
        )

        instance.pcmChannel?.setMessageHandler { message, reply in
            if let data = message as? Data {
                instance.playback?.feed(data)
            }
            reply(nil)
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "start":
            playback?.stop()
            playback = NativeAudioPlayback()
            playback?.start()
            result(nil)

        case "stop":
            playback?.stop()
            playback = nil
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
