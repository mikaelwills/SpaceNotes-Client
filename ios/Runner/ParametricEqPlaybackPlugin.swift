import Flutter

class ParametricEqPlaybackPlugin: NSObject, FlutterPlugin {
    private let playback = ParametricEqPlayback()
    private var channel: FlutterMethodChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ParametricEqPlaybackPlugin()
        let channel = FlutterMethodChannel(
            name: "spacenotes/parametric_eq_playback",
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        instance.playback.onPlaybackStateChanged = { [weak instance] isPlaying in
            DispatchQueue.main.async {
                instance?.channel?.invokeMethod(
                    "playbackStateChanged",
                    arguments: ["isPlaying": isPlaying]
                )
            }
        }
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "load":
            guard let path = args?["path"] as? String else {
                result(FlutterError(code: "bad_args", message: "path required", details: nil))
                return
            }
            let title = args?["title"] as? String ?? (path as NSString).lastPathComponent
            let loaded = playback.load(path: path, title: title)
            if loaded {
                result(true)
            } else {
                result(FlutterError(
                    code: "load_failed",
                    message: playback.lastError ?? "unknown native load failure",
                    details: path
                ))
            }

        case "play":
            playback.play()
            result(nil)

        case "pause":
            playback.pause()
            result(nil)

        case "seek":
            guard let seconds = args?["seconds"] as? Double else {
                result(FlutterError(code: "bad_args", message: "seconds required", details: nil))
                return
            }
            playback.seek(seconds: seconds)
            result(nil)

        case "position":
            result(playback.currentPosition())

        case "duration":
            result(playback.duration())

        case "waveform":
            let binSeconds = args?["binSeconds"] as? Double ?? 0.25
            let playback = self.playback
            DispatchQueue.global(qos: .userInitiated).async {
                let peaks = playback.waveform(binSeconds: binSeconds)
                DispatchQueue.main.async { result(peaks) }
            }

        case "setEq":
            guard let frequency = args?["frequency"] as? Double,
                  let gainDb = args?["gainDb"] as? Double,
                  let bandwidth = args?["bandwidth"] as? Double
            else {
                result(FlutterError(code: "bad_args", message: "frequency, gainDb and bandwidth required", details: nil))
                return
            }
            let band = args?["band"] as? Int ?? 0
            playback.setEq(band: band, frequency: frequency, gainDb: gainDb, bandwidth: bandwidth)
            result(nil)

        case "clearEq":
            playback.clearEq()
            result(nil)

        case "stop":
            playback.stop()
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
