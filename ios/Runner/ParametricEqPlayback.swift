import AVFoundation
import MediaPlayer

final class ParametricEqPlayback {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let eq = AVAudioUnitEQ(numberOfBands: 1)
    private var audioFile: AVAudioFile?
    private var seekOffset: AVAudioFramePosition = 0
    private var isPlaying = false
    private var interruptedPosition: Double?
    private var title = ""
    private var filePath: String?
    private let skipInterval: TimeInterval = 10

    var onPlaybackStateChanged: ((Bool) -> Void)?

    init() {
        configureRemoteCommands()
        eq.bands[0].filterType = .parametric
        eq.bands[0].bypass = true
        eq.bands[0].bandwidth = 0.025

        engine.attach(playerNode)
        engine.attach(eq)
        engine.connect(playerNode, to: eq, format: nil)
        engine.connect(eq, to: engine.mainMixerNode, format: nil)

        let center = NotificationCenter.default
        center.addObserver(
            self,
            selector: #selector(handleEngineConfigurationChange),
            name: .AVAudioEngineConfigurationChange,
            object: engine
        )
        #if os(iOS)
        center.addObserver(
            self,
            selector: #selector(handleSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        #endif
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleEngineConfigurationChange(_ notification: Notification) {
        NSLog("[PARAMETRIC_EQ] engine configuration changed, isPlaying=\(isPlaying)")
        guard isPlaying, audioFile != nil else { return }
        let position = currentPosition()
        playerNode.stop()
        seek(seconds: position)
    }

    #if os(iOS)
    @objc private func handleSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let rawType = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else { return }

        switch type {
        case .began:
            NSLog("[PARAMETRIC_EQ] session interruption began, isPlaying=\(isPlaying)")
            guard isPlaying else { return }
            interruptedPosition = currentPosition()
            playerNode.pause()
        case .ended:
            let rawOptions = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: rawOptions)
            NSLog("[PARAMETRIC_EQ] session interruption ended, shouldResume=\(options.contains(.shouldResume))")
            guard let position = interruptedPosition else { return }
            interruptedPosition = nil
            guard options.contains(.shouldResume), isPlaying else { return }
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                NSLog("[PARAMETRIC_EQ] Failed to reactivate AVAudioSession after interruption: \(error)")
                return
            }
            seek(seconds: position)
        @unknown default:
            break
        }
    }
    #endif

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { [weak self] _ in
            guard let self, self.audioFile != nil else { return .noActionableNowPlayingItem }
            self.play()
            self.onPlaybackStateChanged?(true)
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            guard let self, self.audioFile != nil else { return .noActionableNowPlayingItem }
            self.pause()
            self.onPlaybackStateChanged?(false)
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self, self.audioFile != nil else { return .noActionableNowPlayingItem }
            if self.isPlaying { self.pause() } else { self.play() }
            self.onPlaybackStateChanged?(self.isPlaying)
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self, self.audioFile != nil,
                  let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .noActionableNowPlayingItem }
            self.seek(seconds: event.positionTime)
            return .success
        }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            guard let self, self.audioFile != nil else { return .noActionableNowPlayingItem }
            self.seek(seconds: self.currentPosition() + self.skipInterval)
            return .success
        }
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipInterval)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            guard let self, self.audioFile != nil else { return .noActionableNowPlayingItem }
            self.seek(seconds: self.currentPosition() - self.skipInterval)
            return .success
        }
    }

    private func updateNowPlaying() {
        guard audioFile != nil else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration(),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPosition(),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
    }

    private func ensureEngineRunning() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            NSLog("[PARAMETRIC_EQ] engine restarted")
            return true
        } catch {
            NSLog("[PARAMETRIC_EQ] engine restart failed: \(error)")
            return false
        }
    }

    func load(path: String, title: String) -> Bool {
        NSLog("[PARAMETRIC_EQ] load called, path=\(path)")
        stop()
        self.title = title
        self.filePath = path
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
            updateNowPlaying()
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
            guard ensureEngineRunning() else { return }
            scheduleFromCurrentOffset(file: file)
            playerNode.play()
            NSLog("[PARAMETRIC_EQ] playerNode.play() called, now isPlaying=\(playerNode.isPlaying)")
        }
        isPlaying = true
        updateNowPlaying()
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        updateNowPlaying()
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
            guard ensureEngineRunning() else { return }
            playerNode.play()
        }
        updateNowPlaying()
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

    func setEq(frequency: Double, gainDb: Double, bandwidth: Double) {
        eq.bands[0].frequency = Float(frequency)
        eq.bands[0].gain = Float(gainDb)
        eq.bands[0].bandwidth = Float(bandwidth)
        eq.bands[0].bypass = false
    }

    func clearEq() {
        eq.bands[0].bypass = true
    }

    func stop() {
        playerNode.stop()
        if engine.isRunning {
            engine.stop()
        }
        isPlaying = false
        seekOffset = 0
        audioFile = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil

        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
            NSLog("[PARAMETRIC_EQ] AVAudioSession deactivated")
        } catch {
            NSLog("[PARAMETRIC_EQ] Failed to deactivate AVAudioSession: \(error)")
        }
        #endif
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
