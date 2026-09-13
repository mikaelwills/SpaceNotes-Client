import AVFoundation

final class ParametricEqPlayback {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 2)
    private var audioFile: AVAudioFile?
    private var seekOffset: AVAudioFramePosition = 0
    private var isPlaying = false
    private var filePath: String?

    init() {
        for band in eq.bands {
            band.filterType = .parametric
            band.bypass = true
            band.bandwidth = 0.3
        }

        engine.attach(playerNode)
        engine.attach(eq)
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
    }

    func load(path: String) -> Bool {
        NSLog("[PARAMETRIC_EQ] load called, path=\(path)")
        let url = URL(fileURLWithPath: path)
        NSLog("[PARAMETRIC_EQ] file exists on disk: \(FileManager.default.fileExists(atPath: path))")
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            NSLog("[PARAMETRIC_EQ] open failed \(path): \(error)")
            return false
        }
        NSLog("[PARAMETRIC_EQ] AVAudioFile opened, length=\(file.length) format=\(file.processingFormat)")
        stop()
        filePath = path
        do {
            audioFile = file
            rewireGraph(format: file.processingFormat)

            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            NSLog("[PARAMETRIC_EQ] AVAudioSession activated, category=\(session.category.rawValue)")
            #endif

            NSLog("[PARAMETRIC_EQ] engine.isRunning before start: \(engine.isRunning)")
            if !engine.isRunning {
                try engine.start()
                NSLog("[PARAMETRIC_EQ] engine.start() succeeded")
            }
            return true
        } catch {
            NSLog("[PARAMETRIC_EQ] Failed to load \(path): \(error)")
            return false
        }
    }

    func play() {
        NSLog("[PARAMETRIC_EQ] play called, audioFile=\(audioFile != nil), engine.isRunning=\(engine.isRunning), playerNode.isPlaying=\(playerNode.isPlaying)")
        guard let file = audioFile else {
            NSLog("[PARAMETRIC_EQ] play() aborted, no audioFile loaded")
            return
        }
        if !playerNode.isPlaying {
            playerNode.stop()
            scheduleFromCurrentOffset(file: file)
            playerNode.play()
            NSLog("[PARAMETRIC_EQ] playerNode.play() called, now isPlaying=\(playerNode.isPlaying)")
        }
        isPlaying = true
    }

    func pause() {
        let position = currentPosition()
        playerNode.stop()
        if let file = audioFile {
            seekOffset = frames(forSeconds: position, in: file)
        }
        isPlaying = false
    }

    func seek(seconds: Double) {
        guard let file = audioFile else { return }
        seekOffset = frames(forSeconds: seconds, in: file)

        playerNode.stop()
        scheduleFromCurrentOffset(file: file)
        if isPlaying {
            playerNode.play()
        }
    }

    func currentPosition() -> Double {
        guard let file = audioFile,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return Double(seekOffset) / (audioFile?.processingFormat.sampleRate ?? 1)
        }
        let framesPlayed = seekOffset + playerTime.sampleTime
        return Double(framesPlayed) / file.processingFormat.sampleRate
    }

    func duration() -> Double {
        guard let file = audioFile else { return 0 }
        return Double(file.length) / file.processingFormat.sampleRate
    }

    func waveform(binSeconds: Double) -> [Double] {
        guard let path = filePath else { return [] }
        do {
            let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
            let format = file.processingFormat
            let framesPerBin = max(1, Int(format.sampleRate * binSeconds))
            let totalFrames = Int(file.length)
            guard totalFrames > 0 else { return [] }
            let binCount = (totalFrames + framesPerBin - 1) / framesPerBin
            var peaks = [Float](repeating: 0, count: binCount)

            let chunkFrames: AVAudioFrameCount = 65536
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) else {
                return []
            }
            let channelCount = Int(format.channelCount)
            var frameIndex = 0
            while frameIndex < totalFrames {
                try file.read(into: buffer, frameCount: chunkFrames)
                let frames = Int(buffer.frameLength)
                if frames == 0 { break }
                guard let channels = buffer.floatChannelData else { break }
                for i in 0..<frames {
                    var peak: Float = 0
                    for c in 0..<channelCount {
                        peak = max(peak, abs(channels[c][i]))
                    }
                    let bin = (frameIndex + i) / framesPerBin
                    if peak > peaks[bin] { peaks[bin] = peak }
                }
                frameIndex += frames
            }

            let loudest = peaks.max() ?? 0
            guard loudest > 0 else { return peaks.map { Double($0) } }
            return peaks.map { Double($0 / loudest) }
        } catch {
            NSLog("[PARAMETRIC_EQ] waveform failed for \(path): \(error)")
            return []
        }
    }

    func setEq(band: Int, frequency: Double, gainDb: Double, bandwidth: Double) {
        guard band >= 0 && band < eq.bands.count else { return }
        eq.bands[band].frequency = Float(frequency)
        eq.bands[band].gain = Float(gainDb)
        eq.bands[band].bandwidth = Float(bandwidth)
        eq.bands[band].bypass = false
    }

    func clearEq() {
        for band in eq.bands {
            band.bypass = true
        }
    }

    func stop() {
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
        seekOffset = 0
        audioFile = nil
    }

    private func rewireGraph(format: AVAudioFormat) {
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(eq)
        engine.connect(playerNode, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        NSLog("[PARAMETRIC_EQ] graph rewired at \(format.sampleRate)Hz, mixer=\(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate)Hz")
    }

    private func frames(forSeconds seconds: Double, in file: AVAudioFile) -> AVAudioFramePosition {
        let frames = AVAudioFramePosition(seconds * file.processingFormat.sampleRate)
        return min(max(frames, 0), file.length)
    }

    private func scheduleFromCurrentOffset(file: AVAudioFile) {
        let framesRemaining = AVAudioFrameCount(file.length - seekOffset)
        NSLog("[PARAMETRIC_EQ] scheduleFromCurrentOffset, seekOffset=\(seekOffset) framesRemaining=\(framesRemaining)")
        guard framesRemaining > 0 else {
            NSLog("[PARAMETRIC_EQ] scheduleFromCurrentOffset aborted, no frames remaining")
            return
        }
        file.framePosition = seekOffset
        playerNode.scheduleSegment(
            file,
            startingFrame: seekOffset,
            frameCount: framesRemaining,
            at: nil
        ) {
            NSLog("[PARAMETRIC_EQ] scheduled segment finished playing")
        }
    }
}
