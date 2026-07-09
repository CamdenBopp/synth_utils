//
//  AudioUnitViewController.swift
//  DECtalkVoiceExtension
//
//  Principal class / AUAudioUnitFactory. No custom UI is needed for a
//  speech-provider extension, so this stays minimal.
//

import CoreAudioKit
import os

private let log = Logger(subsystem: "CamdenBopp.DECtalkVoice", category: "AudioUnitViewController")

public class AudioUnitViewController: AUViewController, AUAudioUnitFactory {
    var audioUnit: AUAudioUnit?

    public override func viewDidLoad() {
        super.viewDidLoad()
    }

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let unit = try DECtalkVoiceExtensionAudioUnit(componentDescription: componentDescription, options: [])
        audioUnit = unit
        return unit
    }
}
