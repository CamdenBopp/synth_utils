//
//  ExtensionActivator.swift
//  DECtalkVoice
//
//  On iOS, an AVSpeechSynthesisProviderAudioUnit extension being embedded
//  and correctly declared in Info.plist isn't enough on its own for the
//  system to register its speechVoices — something has to actually
//  instantiate the Audio Unit at least once (which launches the extension
//  process for the first time) before AVSpeechSynthesisVoice.speechVoices()
//  will report anything. This mirrors espeak-ng-ios-app's
//  ManagedAudioUnit.swift, which exists for exactly this reason.
//

import AVFoundation

struct ActivationResult {
    var componentsFound: Int
    var succeeded: Bool
    var lastError: String?
    var attempts: Int
}

enum ExtensionActivator {
    /// The extension's own AudioComponents type/subtype/manufacturer,
    /// from DECtalkVoiceExtension/Info.plist ('ausp' / 'DTiO' / 'Cbop').
    private static func fourCharCode(_ s: String) -> FourCharCode {
        var result: FourCharCode = 0
        for scalar in s.unicodeScalars {
            result = (result << 8) + FourCharCode(scalar.value)
        }
        return result
    }

    static func activate(retries: Int = 5) async -> ActivationResult {
        let description = AudioComponentDescription(
            componentType: fourCharCode("ausp"),
            componentSubType: fourCharCode("DTiO"),
            componentManufacturer: fourCharCode("Cbop"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        var lastComponentsFound = 0
        var lastError: String?

        for attempt in 1...retries {
            let components = AVAudioUnitComponentManager.shared().components(matching: description)
            lastComponentsFound = components.count
            for component in components {
                do {
                    _ = try await AVAudioUnit.instantiate(with: component.audioComponentDescription, options: [.loadOutOfProcess])
                    return ActivationResult(componentsFound: lastComponentsFound, succeeded: true, lastError: nil, attempts: attempt)
                } catch {
                    lastError = "\(error)"
                }
            }
            if attempt < retries {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return ActivationResult(componentsFound: lastComponentsFound, succeeded: false, lastError: lastError, attempts: retries)
    }
}
