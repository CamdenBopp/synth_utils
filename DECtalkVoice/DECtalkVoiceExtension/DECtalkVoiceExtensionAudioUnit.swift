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

        // Strip SSML markup — DECtalkMini's text API takes plain text.
        var text = speechRequest.ssmlRepresentation
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }

        speechBuffer = DECtalkEngine.shared.synthesize(text: text, voiceCode: voice.markupCode, rateWPM: rateWPM)
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
