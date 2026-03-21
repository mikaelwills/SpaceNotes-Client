import AVFoundation
import Flutter
import VideoToolbox

class NativeH264Decoder: NSObject, FlutterTexture {
    private var decompressionSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    private var latestPixelBuffer: CVPixelBuffer?
    private weak var textureRegistry: FlutterTextureRegistry?
    var textureId: Int64 = -1
    private var lastSeq: Int = -1
    private var hasValidReference = false

    func setup(textureRegistry: FlutterTextureRegistry?) {
        self.textureRegistry = textureRegistry
        if let registry = textureRegistry {
            textureId = registry.register(self)
        }
    }

    func decodeFrame(data: Data, seq: Int, isKeyframe: Bool) {
        if lastSeq >= 0 && seq > lastSeq + 1 {
            hasValidReference = false
            destroySession()
        }
        lastSeq = seq

        if isKeyframe {
            hasValidReference = true
        } else if !hasValidReference {
            return
        }

        guard data.count > 4 else { return }

        let paramSetSize = Int(data[0]) | (Int(data[1]) << 8) | (Int(data[2]) << 16) | (Int(data[3]) << 24)
        let avccStart = 4 + paramSetSize
        guard avccStart <= data.count else { return }

        if isKeyframe && paramSetSize > 0 {
            let paramData = data.subdata(in: 4..<avccStart)
            parseAndCreateSession(paramData: paramData)
        }

        guard decompressionSession != nil, avccStart < data.count else { return }

        let avccData = data.subdata(in: avccStart..<data.count)
        decodeAVCC(avccData)
    }

    func stop() {
        destroySession()
        if textureId != -1, let registry = textureRegistry {
            registry.unregisterTexture(textureId)
            textureId = -1
        }
        latestPixelBuffer = nil
        hasValidReference = false
        lastSeq = -1
    }

    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }

    private func parseAndCreateSession(paramData: Data) {
        guard paramData.count >= 4 else { return }

        var offset = 0
        let spsLen = Int(paramData[offset]) << 8 | Int(paramData[offset + 1])
        offset += 2
        guard offset + spsLen + 2 <= paramData.count else { return }
        let spsData = paramData.subdata(in: offset..<(offset + spsLen))
        offset += spsLen

        let ppsLen = Int(paramData[offset]) << 8 | Int(paramData[offset + 1])
        offset += 2
        guard offset + ppsLen <= paramData.count else { return }
        let ppsData = paramData.subdata(in: offset..<(offset + ppsLen))

        createSession(sps: spsData, pps: ppsData)
    }

    private func createSession(sps: Data, pps: Data) {
        destroySession()

        let spsBytes = [UInt8](sps)
        let ppsBytes = [UInt8](pps)

        var formatDesc: CMVideoFormatDescription?

        let status = spsBytes.withUnsafeBufferPointer { spsBuf in
            ppsBytes.withUnsafeBufferPointer { ppsBuf in
                let parameterSetPointers: [UnsafePointer<UInt8>] = [spsBuf.baseAddress!, ppsBuf.baseAddress!]
                let parameterSetSizes: [Int] = [sps.count, pps.count]

                return parameterSetPointers.withUnsafeBufferPointer { ptrBuf in
                    parameterSetSizes.withUnsafeBufferPointer { sizesBuf in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: nil,
                            parameterSetCount: 2,
                            parameterSetPointers: ptrBuf.baseAddress!,
                            parameterSetSizes: sizesBuf.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &formatDesc
                        )
                    }
                }
            }
        }

        guard status == noErr, let desc = formatDesc else { return }
        formatDescription = desc

        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferMetalCompatibilityKey: true
        ]

        let callback: VTDecompressionOutputCallback = { refCon, _, status, _, imageBuffer, _, _ in
            guard status == noErr, let pixelBuffer = imageBuffer, let refCon = refCon else { return }
            let decoder = Unmanaged<NativeH264Decoder>.fromOpaque(refCon).takeUnretainedValue()
            decoder.latestPixelBuffer = pixelBuffer
            if let registry = decoder.textureRegistry {
                DispatchQueue.main.async {
                    registry.textureFrameAvailable(decoder.textureId)
                }
            }
        }

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: callback,
            decompressionOutputRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        var session: VTDecompressionSession?
        VTDecompressionSessionCreate(
            allocator: nil,
            formatDescription: desc,
            decoderSpecification: nil,
            imageBufferAttributes: attrs as CFDictionary,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &session
        )

        decompressionSession = session
    }

    private func decodeAVCC(_ avccData: Data) {
        guard let session = decompressionSession, let formatDesc = formatDescription else { return }

        let dataLength = avccData.count
        var blockBuffer: CMBlockBuffer?

        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: dataLength,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: dataLength,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr, let block = blockBuffer else { return }

        status = avccData.withUnsafeBytes { rawBuf in
            guard let baseAddress = rawBuf.baseAddress else { return OSStatus(-1) }
            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: dataLength
            )
        }
        guard status == noErr else { return }

        var sampleBuffer: CMSampleBuffer?
        var sampleSize = dataLength
        CMSampleBufferCreateReady(
            allocator: nil,
            dataBuffer: block,
            formatDescription: formatDesc,
            sampleCount: 1,
            sampleTimingEntryCount: 0,
            sampleTimingArray: nil,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard let sample = sampleBuffer else { return }

        var infoFlags: VTDecodeInfoFlags = []
        VTDecompressionSessionDecodeFrame(
            session,
            sampleBuffer: sample,
            flags: [],
            frameRefcon: nil,
            infoFlagsOut: &infoFlags
        )
    }

    private func destroySession() {
        if let session = decompressionSession {
            VTDecompressionSessionWaitForAsynchronousFrames(session)
            VTDecompressionSessionInvalidate(session)
            decompressionSession = nil
        }
        formatDescription = nil
    }
}
