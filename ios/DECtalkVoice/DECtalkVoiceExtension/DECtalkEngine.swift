//
//  DECtalkEngine.swift
//  DECtalkVoiceExtension
//
//  Wraps DECtalkMini's classic C API (TextToSpeechInit/Start/Sync, declared
//  in Engine/include/epsonapi.h) — compiled directly into this target from
//  Engine/src/*.c, not dlopen'd, so these are plain direct C calls via the
//  bridging header.
//

import AVFoundation
import os

private let log = Logger(subsystem: "CamdenBopp.DECtalkVoice", category: "DECtalkEngine")

// TextToSpeechInit's callback is a plain C function pointer (short* (*)(short*, long, int))
// with no userdata parameter, so it can't capture a Swift closure's context — accumulate
// into a global buffer instead. DECtalkEngine.synthesize(text:) is effectively single-threaded
// (one utterance synthesized start-to-finish before the next begins), matching how the
// upstream `say` example itself drives this same global/singleton flavor of the API.
private var accumulatedSamples: [Int16] = []

private func ttsCallback(_ buffer: UnsafeMutablePointer<Int16>?, _ length: Int, _ flag: Int32) -> UnsafeMutablePointer<Int16>? {
    if let buffer, length > 0 {
        let bufferPointer = UnsafeBufferPointer(start: buffer, count: length)
        accumulatedSamples.append(contentsOf: bufferPointer)
    }
    return buffer
}

final class DECtalkEngine {
    static let shared = DECtalkEngine()

    private var didInit = false

    private init() {}

    /// DECtalkMini looks for DECtalk.conf next to its own executable first
    /// (via _NSGetExecutablePath on Apple platforms), which for an app
    /// extension is the .appex bundle itself — so as long as DECtalk.conf
    /// and dic/ are bundled as plain resources (landing at the bundle
    /// root on iOS), no chdir workaround is needed here, unlike the
    /// classic Fonix-built engine used on macOS.
    private func initIfNeeded() -> Bool {
        if didInit { return true }
        let result = TextToSpeechInit(ttsCallback, nil)
        didInit = (result == 0)
        if !didInit {
            log.error("TextToSpeechInit failed with code \(result, privacy: .public)")
        }
        return didInit
    }

    // DECtalk's own default rate, in words per minute — confirmed
    // empirically (not documented anywhere we could find): rendering
    // identical text with no rate set and with rate explicitly set to 180
    // produces byte-identical sample counts. SSML <prosody rate="X%"> is a
    // multiplier of "the voice's default rate", so this is the number
    // SpeechRateParser's percentages are multiplied against.
    static let defaultRateWPM = 180

    // DECtalk's valid range, per the classic `say -r` CLI's documented
    // bounds (75-600); TextToSpeechSetRate does no validation of its own,
    // so clamp before calling it.
    static let rateRangeWPM = 75...600

    /// Synchronous by design: AVSpeechSynthesisProviderAudioUnit renders
    /// speech offline, so it's safe (and simplest) to block here.
    func synthesize(text: String, voiceCode: String, rateWPM: Int) -> AVAudioPCMBuffer? {
        guard initIfNeeded() else { return nil }

        accumulatedSamples.removeAll(keepingCapacity: true)

        let clampedRate = min(max(rateWPM, Self.rateRangeWPM.lowerBound), Self.rateRangeWPM.upperBound)
        TextToSpeechSetRate(Int32(clampedRate))

        // DECtalk's classic embedded voice-select markup, e.g. "[:np]" for
        // Paul — prefix it onto the text so this utterance renders in the
        // requested voice.
        let marked = "\(voiceCode)\(text)"

        let startResult: Int32 = marked.withCString { cString in
            TextToSpeechStart(UnsafeMutablePointer(mutating: cString), nil, Int32(WAVE_FORMAT_1M16))
        }
        guard startResult == 0 else {
            log.error("TextToSpeechStart failed with code \(startResult, privacy: .public)")
            return nil
        }

        let syncResult = TextToSpeechSync()
        guard syncResult == 0 else {
            log.error("TextToSpeechSync failed with code \(syncResult, privacy: .public)")
            return nil
        }

        guard !accumulatedSamples.isEmpty else { return nil }

        // WAVE_FORMAT_1M16 = 11025 Hz, mono, 16-bit PCM.
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 11_025, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(accumulatedSamples.count))
        else { return nil }

        buffer.frameLength = AVAudioFrameCount(accumulatedSamples.count)
        let destination = buffer.floatChannelData![0]
        for i in 0..<accumulatedSamples.count {
            destination[i] = Float(accumulatedSamples[i]) / Float(Int16.max)
        }
        return buffer
    }
}
