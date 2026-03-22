import AVFoundation

class NativeAudioCapture {
    private var engine: AVAudioEngine?
    private var onData: ((Data) -> Void)?
    private var outputBuffer = Data()
    private var resamplePhase: Double = 0.0
    private let targetRate: Double = 16000.0
    private let chunkBytes = 640

    func start(onData: @escaping (Data) -> Void) {
        self.onData = onData
        outputBuffer = Data()
        resamplePhase = 0.0

        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.allowBluetooth])
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.005)
            try AVAudioSession.sharedInstance().setActive(true)
            NSLog("[NATIVE_AUDIO] IO buffer duration: \(AVAudioSession.sharedInstance().ioBufferDuration)s")
        } catch {
            NSLog("[NATIVE_AUDIO] Audio session setup failed: \(error)")
        }

        let engine = AVAudioEngine()
        self.engine = engine

        let actualRate = AVAudioSession.sharedInstance().sampleRate
        let ratio = actualRate / targetRate
        let isIntegerRatio = abs(ratio - ratio.rounded()) < 0.001
        let intRatio = Int(ratio.rounded())

        NSLog("[NATIVE_AUDIO] actualRate=\(actualRate) ratio=\(ratio) isInteger=\(isIntegerRatio)")

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, _ in
            guard let self = self, let samples = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)

            if isIntegerRatio && intRatio > 1 {
                for i in stride(from: 0, to: count, by: intRatio) {
                    let clamped = max(-1.0, min(1.0, samples[i]))
                    let int16 = Int16(clamped * 32767.0)
                    var le = int16.littleEndian
                    self.outputBuffer.append(Data(bytes: &le, count: 2))
                    self.flushIfReady()
                }
            } else if ratio > 1.0 {
                var pos = self.resamplePhase
                while Int(pos) + 1 < count {
                    let idx = Int(pos)
                    let frac = Float(pos - Double(idx))
                    let val = samples[idx] * (1.0 - frac) + samples[idx + 1] * frac
                    let clamped = max(-1.0, min(1.0, val))
                    let int16 = Int16(clamped * 32767.0)
                    var le = int16.littleEndian
                    self.outputBuffer.append(Data(bytes: &le, count: 2))
                    self.flushIfReady()
                    pos += ratio
                }
                self.resamplePhase = pos - Double(count)
            } else {
                for i in 0..<count {
                    let clamped = max(-1.0, min(1.0, samples[i]))
                    let int16 = Int16(clamped * 32767.0)
                    var le = int16.littleEndian
                    self.outputBuffer.append(Data(bytes: &le, count: 2))
                    self.flushIfReady()
                }
            }
        }

        do {
            try engine.start()
            NSLog("[NATIVE_AUDIO] Engine started")
        } catch {
            NSLog("[NATIVE_AUDIO] Engine start failed: \(error)")
        }
    }

    private func flushIfReady() {
        while outputBuffer.count >= chunkBytes {
            let chunk = Data(outputBuffer.prefix(chunkBytes))
            outputBuffer.removeFirst(chunkBytes)
            onData?(chunk)
        }
    }

    func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        onData = nil
        outputBuffer = Data()
        NSLog("[NATIVE_AUDIO] Stopped")
    }
}
