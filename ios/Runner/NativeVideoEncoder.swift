import AVFoundation
import CoreImage
import Flutter
import UIKit
import VideoToolbox

struct EncodedFrame {
    let data: Data
    let codec: UInt8
    let isKeyframe: Bool
    let encodeMicros: UInt32
}

class NativeVideoEncoder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, FlutterTexture {
    private var captureSession: AVCaptureSession?
    private let processingQueue = DispatchQueue(label: "spacenotes.video.encoder", qos: .userInteractive)
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private var targetFps: Double = 30
    private var jpegQuality: CGFloat = 0.8
    private var lastFrameTime: CMTime = .zero
    private var onFrame: ((EncodedFrame) -> Void)?
    private var codecMode: String = "jpeg"

    private var latestPixelBuffer: CVPixelBuffer?
    private weak var textureRegistry: FlutterTextureRegistry?
    var textureId: Int64 = -1

    private var compressionSession: VTCompressionSession?
    private var frameCount: Int = 0
    private var keyframeInterval: Int = 20
    private var h264EncodeStart: CFAbsoluteTime = 0

    private var currentPosition: AVCaptureDevice.Position = .front
    private var currentFps: Int = 20
    private var currentWidth: Int = 1920
    private var currentHeight: Int = 1080

    func start(fps: Int, width: Int, height: Int, quality: Double, codec: String, cameraPosition: String = "front", textureRegistry: FlutterTextureRegistry?, onFrame: @escaping (EncodedFrame) -> Void) {
        currentPosition = cameraPosition == "back" ? .back : .front
        currentFps = fps
        currentWidth = width
        currentHeight = height
        self.targetFps = Double(fps)
        self.jpegQuality = CGFloat(quality)
        self.onFrame = onFrame
        self.lastFrameTime = .zero
        self.textureRegistry = textureRegistry
        self.codecMode = codec
        self.keyframeInterval = fps
        self.frameCount = 0

        if let registry = textureRegistry {
            textureId = registry.register(self)
        }

        if codec == "h264" {
            setupH264Encoder(width: width, height: height, fps: fps, bitrate: 10_000_000)
        }

        let session = AVCaptureSession()

        let preset = presetForSize(width: width, height: height)
        if session.canSetSessionPreset(preset) {
            session.sessionPreset = preset
        } else {
            session.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition) else { return }

        do {
            try device.lockForConfiguration()
            device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(fps))
            device.unlockForConfiguration()
        } catch {}

        guard let input = try? AVCaptureDeviceInput(device: device) else { return }
        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: processingQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        if let connection = output.connection(with: .video) {
            connection.videoOrientation = .portrait
            if connection.isVideoMirroringSupported {
                connection.isVideoMirrored = (currentPosition == .front)
            }
        }

        captureSession = session
        session.startRunning()
    }

    func switchCamera() {
        guard let onFrame = self.onFrame else { return }
        let newPosition: AVCaptureDevice.Position = (currentPosition == .front) ? .back : .front
        let codec = self.codecMode
        let quality = Double(self.jpegQuality)
        let registry = self.textureRegistry

        stop()
        start(fps: currentFps, width: currentWidth, height: currentHeight, quality: quality, codec: codec, cameraPosition: newPosition == .back ? "back" : "front", textureRegistry: registry, onFrame: onFrame)
    }

    func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        onFrame = nil
        if textureId != -1, let registry = textureRegistry {
            registry.unregisterTexture(textureId)
            textureId = -1
        }
        latestPixelBuffer = nil
        if let session = compressionSession {
            VTCompressionSessionInvalidate(session)
            compressionSession = nil
        }
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        latestPixelBuffer = pixelBuffer
        if let registry = textureRegistry {
            DispatchQueue.main.async {
                registry.textureFrameAvailable(self.textureId)
            }
        }

        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let minInterval = CMTimeMake(value: 1, timescale: Int32(targetFps))

        if lastFrameTime != .zero && CMTimeSubtract(timestamp, lastFrameTime) < minInterval {
            return
        }
        lastFrameTime = timestamp

        if codecMode == "h264" {
            encodeH264(pixelBuffer: pixelBuffer, timestamp: timestamp)
        } else {
            encodeJpeg(pixelBuffer: pixelBuffer)
        }
    }

    private func encodeJpeg(pixelBuffer: CVPixelBuffer) {
        autoreleasepool {
            let encodeStart = CFAbsoluteTimeGetCurrent()

            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let colorSpace = CGColorSpaceCreateDeviceRGB()

            guard let jpegData = ciContext.jpegRepresentation(of: ciImage, colorSpace: colorSpace, options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: jpegQuality]) else { return }

            let encodeMicros = UInt32((CFAbsoluteTimeGetCurrent() - encodeStart) * 1_000_000)

            onFrame?(EncodedFrame(data: jpegData, codec: 0, isKeyframe: true, encodeMicros: encodeMicros))
        }
    }

    private func setupH264Encoder(width: Int, height: Int, fps: Int, bitrate: Int) {
        let callback: VTCompressionOutputCallback = { outputCallbackRefCon, _, status, infoFlags, sampleBuffer in
            guard status == noErr, let sampleBuffer = sampleBuffer, let refCon = outputCallbackRefCon else { return }
            let encoder = Unmanaged<NativeVideoEncoder>.fromOpaque(refCon).takeUnretainedValue()
            encoder.handleH264Output(sampleBuffer: sampleBuffer)
        }

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: nil,
            compressedDataAllocator: nil,
            outputCallback: callback,
            refcon: Unmanaged.passUnretained(self).toOpaque(),
            compressionSessionOut: &session
        )

        guard status == noErr, let session = session else { return }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: NSNumber(value: keyframeInterval))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: NSNumber(value: bitrate))
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)

        VTCompressionSessionPrepareToEncodeFrames(session)
        compressionSession = session
    }

    private func encodeH264(pixelBuffer: CVPixelBuffer, timestamp: CMTime) {
        guard let session = compressionSession else { return }

        h264EncodeStart = CFAbsoluteTimeGetCurrent()
        frameCount += 1

        var properties: CFDictionary? = nil
        if frameCount % keyframeInterval == 1 {
            properties = [kVTEncodeFrameOptionKey_ForceKeyFrame: true] as CFDictionary
        }

        VTCompressionSessionEncodeFrame(session, imageBuffer: pixelBuffer, presentationTimeStamp: timestamp, duration: .invalid, frameProperties: properties, sourceFrameRefcon: nil, infoFlagsOut: nil)
    }

    private func handleH264Output(sampleBuffer: CMSampleBuffer) {
        let encodeMicros = UInt32((CFAbsoluteTimeGetCurrent() - h264EncodeStart) * 1_000_000)

        let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]]
        let isKeyframe = !(attachments?.first?[kCMSampleAttachmentKey_NotSync] as? Bool ?? false)

        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }

        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer)

        guard let pointer = dataPointer else { return }

        var frameData = Data()

        if isKeyframe {
            if let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                var spsSize: Int = 0
                var spsPointer: UnsafePointer<UInt8>?
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, parameterSetIndex: 0, parameterSetPointerOut: &spsPointer, parameterSetSizeOut: &spsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)

                var ppsSize: Int = 0
                var ppsPointer: UnsafePointer<UInt8>?
                CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, parameterSetIndex: 1, parameterSetPointerOut: &ppsPointer, parameterSetSizeOut: &ppsSize, parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil)

                if let sps = spsPointer, let pps = ppsPointer {
                    var spsLen = UInt16(spsSize).bigEndian
                    var ppsLen = UInt16(ppsSize).bigEndian
                    frameData.append(Data(bytes: &spsLen, count: 2))
                    frameData.append(sps, count: spsSize)
                    frameData.append(Data(bytes: &ppsLen, count: 2))
                    frameData.append(pps, count: ppsSize)
                }
            }
        }

        let paramSetSize = UInt32(frameData.count)
        var paramHeader = Data(count: 4)
        var ps = paramSetSize.littleEndian
        paramHeader.replaceSubrange(0..<4, with: Data(bytes: &ps, count: 4))

        var output = paramHeader
        output.append(frameData)
        output.append(Data(bytes: pointer, count: totalLength))

        onFrame?(EncodedFrame(data: output, codec: 1, isKeyframe: isKeyframe, encodeMicros: encodeMicros))
    }

    private func presetForSize(width: Int, height: Int) -> AVCaptureSession.Preset {
        let pixels = width * height
        if pixels >= 3840 * 2160 { return .hd4K3840x2160 }
        if pixels >= 2560 * 1440 { return .hd4K3840x2160 }
        if pixels >= 1920 * 1080 { return .hd1920x1080 }
        if pixels >= 1280 * 720 { return .hd1280x720 }
        if pixels >= 640 * 480 { return .vga640x480 }
        return .low
    }
}
