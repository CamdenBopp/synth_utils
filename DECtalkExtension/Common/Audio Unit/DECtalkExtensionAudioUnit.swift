//
//  DECtalkExtensionAudioUnit.swift
//  DECtalkExtension
//
//  Created by Camden Bopp on 12/4/25.
//

// NOTE:- An Audio Unit Speech Extension (ausp) is rendered offline, so it is safe to use
// Swift in this case. It is not recommended to use Swift in other AU types.

import AVFoundation

public class DECtalkExtensionAudioUnit: AVSpeechSynthesisProviderAudioUnit, @unchecked Sendable
{
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!

    private var format: AVAudioFormat

	private var linearGain = AUValue(0.25)

    private var speechBuffer: AVAudioPCMBuffer?
    private var renderPosition: AVAudioFramePosition = 0

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {
        // DECtalk's classic wave-out API renders 16-bit PCM at 11025 Hz; matching that
        // natively here avoids needing to resample the synthesized buffer.
        let basicDescription = AudioStreamBasicDescription(mSampleRate: 11_025.0,
														   mFormatID: kAudioFormatLinearPCM,
														   mFormatFlags: kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved,
														   mBytesPerPacket: 4,
														   mFramesPerPacket: 1,
														   mBytesPerFrame: 4,
														   mChannelsPerFrame: 1,
														   mBitsPerChannel: 32,
														   mReserved: 0);

        self.format = AVAudioFormat(cmAudioFormatDescription: try! CMAudioFormatDescription(audioStreamBasicDescription: basicDescription));

        outputBus = try AUAudioUnitBus(format: self.format)
        try super.init(componentDescription: componentDescription, options: options)
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
    }

    public override var channelCapabilities: [NSNumber] {
        get {
            return [NSNumber(value: 0), NSNumber(value: 1)]
        }
    }

	public func setupParameterTree(_ parameterTree: AUParameterTree) {
		self.parameterTree = parameterTree

		// Set the Parameter default values before setting up the parameter callbacks
		for param in parameterTree.allParameters {
			setParameter(paramAddress: param.address, value: param.value)
		}

		setupParameterCallbacks()
	}

	private func setupParameterCallbacks() {
		 // implementorValueObserver is called when a parameter changes value.
		parameterTree?.implementorValueObserver = { [weak self] param, value -> Void in
			self?.setParameter(paramAddress: param.address, value: value)
		}

		// implementorValueProvider is called when the value needs to be refreshed.
		parameterTree?.implementorValueProvider = { [weak self] param in
			return self!.getParameter(param.address)
		}

		// A function to provide string representations of parameter values.
		parameterTree?.implementorStringFromValueCallback = { param, valuePtr in
			guard let value = valuePtr?.pointee else {
			   return "-"
			}
			return NSString.localizedStringWithFormat("%.f", value) as String
		}
	}

	// MARK:- Parameter Setter / Getter
	func setParameter(paramAddress: AUParameterAddress, value: AUValue) {
		switch paramAddress {
		case DECtalkExtensionParameterAddress.gain.rawValue:
			linearGain = value
		default:
			return
		}
	}

	func getParameter(_ paramAddress: AUParameterAddress) -> AUValue {
		switch paramAddress {
		case DECtalkExtensionParameterAddress.gain.rawValue:
			return linearGain
		default:
			return 0.0
		}
	}

	// MARK:- Rendering
	/*
	 NOTE:- It is only safe to use Swift for audio rendering in this case, as Audio Unit Speech Extensions process offline.
	 (Swift is not usually recommended for processing on the realtime audio thread)
	 */
    public override var internalRenderBlock: AUInternalRenderBlock
    {
        return { [weak self] actionFlags, timestamp, frameCount, outputBusNumber, outputAudioBufferList, _, _ in
            guard let self,
                  let speechBuffer = self.speechBuffer,
                  let source = speechBuffer.floatChannelData?[0]
            else {
                actionFlags.pointee = AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete.rawValue
                return noErr
            }

            let unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)[0]
            let destination = unsafeBuffer.mData!.assumingMemoryBound(to: Float32.self)
            let gain = self.linearGain

            var written = 0
            while written < Int(frameCount) {
                if self.renderPosition >= AVAudioFramePosition(speechBuffer.frameLength) {
                    actionFlags.pointee = AudioUnitRenderActionFlags.offlineUnitRenderAction_Complete.rawValue
                    break
                }
                destination[written] = source[Int(self.renderPosition)] * gain
                self.renderPosition += 1
                written += 1
            }

            return noErr
        }
    }

    public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
        renderPosition = 0

        let voice = DECtalkVoice.from(identifier: speechRequest.voice.identifier)

        // Strip SSML markup — DECtalk's classic text API takes plain text.
        var text = speechRequest.ssmlRepresentation
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            text = regex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(text.startIndex..., in: text),
                withTemplate: ""
            )
        }

        speechBuffer = DECtalkEngine.shared.synthesize(text: text, speaker: voice.speakerID)
    }

    public override func cancelSpeechRequest() {
        speechBuffer = nil
        renderPosition = 0
        NSLog("Stop synthesizing")
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
