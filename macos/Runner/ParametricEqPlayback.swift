import AVFoundation

final class ParametricEqPlayback {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private var audioFile: AVAudioFile?
    private var seekOffset: AVAudioFramePosition = 0
    private var isPlaying = false

    init() {
        eq.bands[0].filterType = .parametric
        eq.bands[0].bypass = true
        eq.bands[0].bandwidth = 0.1

        engine.attach(playerNode)
        engine.attach(eq)
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)
    }

    func load(path: String) -> Bool {
        NSLog("[PARAMETRIC_EQ] load called, path=\(path)")
        stop()
        do {
            let url = URL(fileURLWithPath: path)
            NSLog("[PARAMETRIC_EQ] file exists on disk: \(FileManager.default.fileExists(atPath: path))")
            let file = try AVAudioFile(forReading: url)
            NSLog("[PARAMETRIC_EQ] AVAudioFile opened, length=\(file.length) format=\(file.processingFormat)")
            audioFile = file
            engine.disconnectNodeOutput(playerNode)
            engine.connect(playerNode, to: eq, format: file.processingFormat)

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
            scheduleFromCurrentOffset(file: file)
            playerNode.play()
            NSLog("[PARAMETRIC_EQ] playerNode.play() called, now isPlaying=\(playerNode.isPlaying)")
        }
        isPlaying = true
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
    }

    func seek(seconds: Double) {
        guard let file = audioFile else { return }
        let sampleRate = file.processingFormat.sampleRate
        seekOffset = AVAudioFramePosition(seconds * sampleRate)
        if seekOffset < 0 { seekOffset = 0 }
        if seekOffset > file.length { seekOffset = file.length }

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

    func setEq(frequency: Double, gainDb: Double) {
        eq.bands[0].frequency = Float(frequency)
        eq.bands[0].gain = Float(gainDb)
        eq.bands[0].bypass = false
    }

    func clearEq() {
        eq.bands[0].bypass = true
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        seekOffset = 0
        audioFile = nil
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
