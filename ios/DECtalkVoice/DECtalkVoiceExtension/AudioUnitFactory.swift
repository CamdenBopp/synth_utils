//
//  AudioUnitFactory.swift
//  DECtalkVoiceExtension
//
//  Principal class / AUAudioUnitFactory. Matches the pattern used by
//  Apple's own official AVSpeechSynthesisProviderAudioUnit sample
//  (bocoup/apple-custom-speech-synthesizer) and the actually-shipped
//  espeak-ng-ios-app: a plain NSObject implementing AUAudioUnitFactory,
//  not an AUViewController — a speech provider extension doesn't need a
//  UI view controller at all, and using one is a needless deviation from
//  what both known-working references do.
//

import CoreAudioKit

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?

    public func beginRequest(with context: NSExtensionContext) {}

    @objc
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        audioUnit = try DECtalkVoiceExtensionAudioUnit(componentDescription: componentDescription, options: [])
        return audioUnit!
    }
}
