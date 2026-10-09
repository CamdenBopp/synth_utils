//
//  DECtalkVoiceExtensionAudioUnit.swift
//  DECtalkVoiceExtension
//
//  NOTE: An Audio Unit Speech Extension (ausp) renders offline, so it's
//  safe to use Swift here even though that's usually discouraged for
//  other AU types on the realtime render thread.
//

import AVFoundation
import os

private let log = Logger(subsystem: "CamdenBopp.DECtalkVoice", category: "DECtalkVoiceExtensionAudioUnit")

public class DECtalkVoiceExtensionAudioUnit: AVSpeechSynthesisProviderAudioUnit, @unchecked Sendable {
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!

    private var format: AVAudioFormat

    private var speechBuffer: AVAudioPCMBuffer?
    private var renderPosition: AVAudioFramePosition = 0

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        // DECtalkMini's classic wave-out format is 16-bit PCM at 11025 Hz;
        // matching that natively here avoids resampling.
        let basicDescription = AudioStreamBasicDescription(mSampleRate: 11_025.0,
                                                             mFormatID: kAudioFormatLinearPCM,
                                                             mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
                                                             mBytesPerPacket: 4,
                                                             mFramesPerPacket: 1,
                                                             mBytesPerFrame: 4,
                                                             mChannelsPerFrame: 1,
                                                             mBitsPerChannel: 32,
                                                             mReserved: 0)

        self.format = AVAudioFormat(cmAudioFormatDescription: try! CMAudioFormatDescription(audioStreamBasicDescription: basicDescription))

        outputBus = try AUAudioUnitBus(format: self.format)
        try super.init(componentDescription: componentDescription, options: options)
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: .output, busses: [outputBus])
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
    }

    public override var channelCapabilities: [NSNumber] {
        [NSNumber(value: 0), NSNumber(value: 1)]
    }

    public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
        renderPosition = 0

        let voice = DECtalkVoice.from(identifier: speechRequest.voice.identifier)

        // Read <prosody rate="..."> before stripping SSML markup — this is
        // how the rate slider/rotor (VoiceOver, and Settings > Accessibility
        // > Spoken Content) actually communicates its setting; there's no
        // separate rate field on the request to read instead.
        let rateMultiplier = SSMLProsody.rateMultiplier(in: speechRequest.ssmlRepresentation)
        let rateWPM = Int((Double(DECtalkEngine.defaultRateWPM) * rateMultiplier).rounded())
        log.notice("ssml=\(speechRequest.ssmlRepresentation, privacy: .public) rateMultiplier=\(rateMultiplier, privacy: .public) rateWPM=\(rateWPM, privacy: .public)")

        // DECtalk's text engine has no concept of a pause duration, so
        // <break time="..."/> (how VoiceOver asks for the gap before a
        // hint, and any other authored pause) has to be handled here: pull
        // the breaks out as their own segments up front, synthesize each
        // text run around them separately, and splice in real silence of
        // the requested length when stitching everything back together.
        let segments = SSMLBreaks.segment(speechRequest.ssmlRepresentation)
        var buffers: [AVAudioPCMBuffer] = []
        for segment in segments {
            switch segment {
            case .text(let raw):
                let stripped = Self.stripTags(raw)
                guard !stripped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                if let buffer = DECtalkEngine.shared.synthesize(text: stripped, voiceCode: voice.markupCode, rateWPM: rateWPM) {
                    buffers.append(buffer)
                }
            case .pause(let duration):
                if let buffer = silenceBuffer(duration: duration) {
                    buffers.append(buffer)
                }
            }
        }

        speechBuffer = Self.concatenate(buffers)
    }

    // DECtalkMini's text API takes plain text — SSML markup other than
    // <break>, which SSMLBreaks.segment already pulled out, still needs
    // stripping (e.g. <prosody> tags left in a text segment).
    private static func stripTags(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) else { return text }
        let stripped = regex.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: ""
        )
        return normalizeWhitespace(stripped)
    }

    // Accessibility labels sourced from web/Electron-style UIs commonly
    // contain U+00A0 (non-breaking space, the usual result of &nbsp; in
    // rendered HTML) or other Unicode whitespace instead of a plain ASCII
    // space — visually and even in a text field they look and copy/paste
    // identical to a normal space, but DECtalk's classic tokenizer only
    // treats 0x20 as a word boundary, so words on either side get run
    // together with no audible gap. Normalize every Unicode whitespace
    // character (and known zero-width spacing characters, which aren't in
    // CharacterSet.whitespacesAndNewlines) to a plain space before this
    // reaches the engine.
    private static func normalizeWhitespace(_ text: String) -> String {
        let zeroWidth = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}")
        let toNormalize = CharacterSet.whitespacesAndNewlines.union(zeroWidth)
        return String(text.unicodeScalars.map { toNormalize.contains($0) ? " " : Character($0) })
    }

    private func silenceBuffer(duration: TimeInterval) -> AVAudioPCMBuffer? {
        let frameCount = AUAudioFrameCount(max(0, (duration * format.sampleRate).rounded()))
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount
        if let destination = buffer.floatChannelData?[0] {
            destination.update(repeating: 0, count: Int(frameCount))
        }
        return buffer
    }

    private static func concatenate(_ buffers: [AVAudioPCMBuffer]) -> AVAudioPCMBuffer? {
        guard let format = buffers.first?.format else { return nil }
        let totalFrames = buffers.reduce(AVAudioFrameCount(0)) { $0 + $1.frameLength }
        guard totalFrames > 0, let combined = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else { return nil }
        combined.frameLength = totalFrames

        guard let destination = combined.floatChannelData?[0] else { return nil }
        var offset = 0
        for buffer in buffers {
            guard let source = buffer.floatChannelData?[0] else { continue }
            let count = Int(buffer.frameLength)
            destination.advanced(by: offset).update(from: source, count: count)
            offset += count
        }
        return combined
    }

    public override func cancelSpeechRequest() {
        speechBuffer = nil
        renderPosition = 0
    }

    public override var internalRenderBlock: AUInternalRenderBlock {
        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputAudioBufferList, _, _ in
            guard let self,
                  let speechBuffer = self.speechBuffer,
                  let source = speechBuffer.floatChannelData?[0]
            else {
                actionFlags.pointee = .offlineUnitRenderAction_Complete
                return noErr
            }

            let unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)[0]
            let destination = unsafeBuffer.mData!.assumingMemoryBound(to: Float32.self)

            var written = 0
            while written < Int(frameCount) {
                if self.renderPosition >= AVAudioFramePosition(speechBuffer.frameLength) {
                    actionFlags.pointee = .offlineUnitRenderAction_Complete
                    break
                }
                destination[written] = source[Int(self.renderPosition)]
                self.renderPosition += 1
                written += 1
            }

            return noErr
        }
    }

    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        get {
            DECtalkVoice.allCases.map { voice in
                AVSpeechSynthesisProviderVoice(
                    name: voice.displayName,
                    identifier: voice.identifier,
                    primaryLanguages: ["en-US"],
                    supportedLanguages: ["en-US"]
                )
            }
        }
        set { }
    }
}
