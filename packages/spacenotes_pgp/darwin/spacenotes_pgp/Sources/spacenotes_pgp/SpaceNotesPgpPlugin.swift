import Foundation
import SpaceNotesPGP

#if os(iOS)
  import Flutter
#else
  import FlutterMacOS
#endif

public class SpaceNotesPgpPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
      let messenger = registrar.messenger()
    #else
      let messenger = registrar.messenger
    #endif
    let channel = FlutterMethodChannel(
      name: "spacenotes/pgp", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(SpaceNotesPgpPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "decrypt":
      handleDecrypt(call, result: result)
    case "encrypt":
      handleEncrypt(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleEncrypt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let plaintext = (args["plaintext"] as? FlutterStandardTypedData)?.data,
      let publicKeys = (args["publicKeys"] as? FlutterStandardTypedData)?.data,
      let gpgId = (args["gpgId"] as? FlutterStandardTypedData)?.data
    else {
      result(
        FlutterError(
          code: "bad_arguments",
          message: "encrypt needs plaintext, publicKeys and gpgId as byte arrays",
          details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      var error: NSError?
      let ciphertext = PgpmobileEncrypt(plaintext, publicKeys, gpgId, &error)

      DispatchQueue.main.async {
        if let error = error {
          result(
            FlutterError(
              code: "encrypt_failed",
              message: error.localizedDescription,
              details: nil))
          return
        }
        guard let ciphertext = ciphertext, !ciphertext.isEmpty else {
          result(
            FlutterError(
              code: "encrypt_failed", message: "no ciphertext returned", details: nil))
          return
        }
        result(FlutterStandardTypedData(bytes: ciphertext))
      }
    }
  }

  private func handleDecrypt(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let ciphertext = (args["ciphertext"] as? FlutterStandardTypedData)?.data,
      let privateKey = (args["privateKey"] as? FlutterStandardTypedData)?.data
    else {
      result(
        FlutterError(
          code: "bad_arguments",
          message: "decrypt needs ciphertext and privateKey as byte arrays",
          details: nil))
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      var error: NSError?
      let plaintext = PgpmobileDecrypt(ciphertext, privateKey, &error)

      DispatchQueue.main.async {
        if let error = error {
          result(
            FlutterError(
              code: "decrypt_failed",
              message: error.localizedDescription,
              details: nil))
          return
        }
        guard let plaintext = plaintext else {
          result(
            FlutterError(
              code: "decrypt_failed", message: "no plaintext returned", details: nil))
          return
        }
        result(FlutterStandardTypedData(bytes: plaintext))
      }
    }
  }
}
