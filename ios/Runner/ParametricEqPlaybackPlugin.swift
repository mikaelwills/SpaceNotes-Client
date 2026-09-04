import Flutter

class ParametricEqPlaybackPlugin: NSObject, FlutterPlugin {
    private let playback = ParametricEqPlayback()

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ParametricEqPlaybackPlugin()
        let channel = FlutterMethodChannel(
            name: "spacenotes/parametric_eq_playback",
            binaryMessenger: registrar.messenger()
        )
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
            result(playback.load(path: path))

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

        case "setEq":
            guard let frequency = args?["frequency"] as? Double,
                  let gainDb = args?["gainDb"] as? Double,
                  let bandwidth = args?["bandwidth"] as? Double
            else {
                result(FlutterError(code: "bad_args", message: "frequency, gainDb and bandwidth required", details: nil))
                return
            }
            playback.setEq(frequency: frequency, gainDb: gainDb, bandwidth: bandwidth)
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
