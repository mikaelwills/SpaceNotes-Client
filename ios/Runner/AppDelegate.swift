import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    NativeVideoEncoderPlugin.register(with: self.registrar(forPlugin: "NativeVideoEncoderPlugin")!)
    NativeH264DecoderPlugin.register(with: self.registrar(forPlugin: "NativeH264DecoderPlugin")!)
    NativeAudioCapturePlugin.register(with: self.registrar(forPlugin: "NativeAudioCapturePlugin")!)
    NativeAudioPlaybackPlugin.register(with: self.registrar(forPlugin: "NativeAudioPlaybackPlugin")!)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
