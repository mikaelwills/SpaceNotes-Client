import AVFoundation
import AudioToolbox

class NativeAudioPlayback {
    private var audioUnit: AudioComponentInstance?
    private var buffer = Data()
    private let lock = NSLock()
    private let maxBufferBytes = 640 * 6

    func start() {
        var desc = AudioComponentDescription()
        desc.componentType = kAudioUnitType_Output
        desc.componentSubType = kAudioUnitSubType_RemoteIO
        desc.componentFlags = 0
        desc.componentFlagsMask = 0
        desc.componentManufacturer = kAudioUnitManufacturer_Apple

        guard let component = AudioComponentFindNext(nil, &desc) else { return }
        var unit: AudioComponentInstance?
        guard AudioComponentInstanceNew(component, &unit) == noErr, let unit = unit else { return }
        audioUnit = unit

        var format = AudioStreamBasicDescription()
        format.mSampleRate = 16000
        format.mFormatID = kAudioFormatLinearPCM
        format.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked
        format.mFramesPerPacket = 1
        format.mChannelsPerFrame = 1
        format.mBitsPerChannel = 16
        format.mBytesPerFrame = 2
        format.mBytesPerPacket = 2

        AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &format, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))

        var callback = AURenderCallbackStruct(
            inputProc: { (inRefCon, _, _, _, inNumberFrames, ioData) -> OSStatus in
                let playback = Unmanaged<NativeAudioPlayback>.fromOpaque(inRefCon).takeUnretainedValue()
                guard let bufferList = ioData else { return noErr }
                let buffer = bufferList.pointee.mBuffers
                let bytesNeeded = Int(inNumberFrames) * 2

                playback.lock.lock()
                let available = playback.buffer.count

                if available >= bytesNeeded {
                    playback.buffer.copyBytes(to: buffer.mData!.assumingMemoryBound(to: UInt8.self), count: bytesNeeded)
                    playback.buffer.removeFirst(bytesNeeded)
                } else if available > 0 {
                    playback.buffer.copyBytes(to: buffer.mData!.assumingMemoryBound(to: UInt8.self), count: available)
                    memset(buffer.mData! + available, 0, bytesNeeded - available)
                    playback.buffer.removeAll()
                } else {
                    memset(buffer.mData!, 0, bytesNeeded)
                }
                playback.lock.unlock()

                return noErr
            },
            inputProcRefCon: Unmanaged.passUnretained(self).toOpaque()
        )

        AudioUnitSetProperty(unit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &callback, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        AudioUnitInitialize(unit)
        AudioOutputUnitStart(unit)

        NSLog("[NATIVE_AUDIO_PLAYBACK] Started")
    }

    func feed(_ data: Data) {
        lock.lock()
        buffer.append(data)
        if buffer.count > maxBufferBytes {
            buffer.removeFirst(buffer.count - maxBufferBytes)
        }
        lock.unlock()
    }

    func stop() {
        if let unit = audioUnit {
            AudioOutputUnitStop(unit)
            AudioUnitUninitialize(unit)
            AudioComponentInstanceDispose(unit)
            audioUnit = nil
        }
        lock.lock()
        buffer.removeAll()
        lock.unlock()
        NSLog("[NATIVE_AUDIO_PLAYBACK] Stopped")
    }
}
