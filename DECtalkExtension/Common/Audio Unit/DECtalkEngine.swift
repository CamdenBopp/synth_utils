//
//  DECtalkEngine.swift
//  DECtalkExtension
//

import AVFoundation

enum DECtalkVoice: String, CaseIterable {
    case paul, betty, harry, frank, dennis, kit, ursula, rita, wendy

    var speakerID: UInt32 {
        UInt32(Self.allCases.firstIndex(of: self)!)
    }

    var identifier: String { "CamdenBopp.DECtalk.\(rawValue)" }
    var displayName: String { "DECtalk \(rawValue.capitalized)" }

    static func from(identifier: String) -> DECtalkVoice {
        let key = identifier.split(separator: ".").last.map(String.init) ?? ""
        return DECtalkVoice(rawValue: key) ?? .paul
    }
}

/// Loads the vendored DECtalk engine (Engine/lib/libtts.dylib, bundled as an extension
/// resource) and renders text to a PCM buffer via the classic DECtalk C API
/// (TextToSpeechStartup/Speak/...). Symbols are resolved with dlopen/dlsym rather than
/// linked at build time, so the vendored dylib only needs to be a bundled resource — no
/// bridging header or "Link Binary With Libraries" entry required.
final class DECtalkEngine {
    static let shared = DECtalkEngine()

    private typealias StartupFn = @convention(c) (UnsafeMutablePointer<UnsafeMutableRawPointer?>?, UInt32, UInt32, UnsafeRawPointer?, Int32) -> UInt32
    private typealias ShutdownFn = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
    private typealias OpenWaveOutFileFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt32) -> UInt32
    private typealias CloseWaveOutFileFn = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
    private typealias SpeakFn = @convention(c) (UnsafeMutableRawPointer?, UnsafePointer<CChar>?, UInt32) -> UInt32
    private typealias SyncFn = @convention(c) (UnsafeMutableRawPointer?) -> UInt32
    private typealias SetSpeakerFn = @convention(c) (UnsafeMutableRawPointer?, UInt32) -> UInt32

    private var engineDirectory: String?
    private var startup: StartupFn?
    private var shutdown: ShutdownFn?
    private var openWaveOutFile: OpenWaveOutFileFn?
    private var closeWaveOutFile: CloseWaveOutFileFn?
    private var speak: SpeakFn?
    private var sync: SyncFn?
    private var setSpeaker: SetSpeakerFn?
    private var didAttemptLoad = false

    private init() {}

    private func loadIfNeeded() -> Bool {
        if didAttemptLoad { return startup != nil }
        didAttemptLoad = true

        let bundle = Bundle(for: DECtalkExtensionAudioUnit.self)
        // DECtalk.conf + dtalk_us.dic are bundled resources (flat, in Contents/Resources);
        // DECtalk resolves both relative to the process's cwd.
        guard let resourcePath = bundle.resourcePath else {
            NSLog("DECtalk: extension has no resource path")
            return false
        }
        engineDirectory = resourcePath

        // libtts.dylib is embedded (Embed & Sign) into Contents/Frameworks.
        guard let frameworksPath = bundle.privateFrameworksPath else {
            NSLog("DECtalk: extension has no Frameworks path")
            return false
        }
        guard let dylib = dlopen(frameworksPath + "/libtts.dylib", RTLD_NOW | RTLD_LOCAL) else {
            NSLog("DECtalk: dlopen(libtts.dylib) failed: \(String(cString: dlerror()))")
            return false
        }

        func resolve<T>(_ name: String, as _: T.Type) -> T? {
            guard let symbol = dlsym(dylib, name) else { return nil }
            return unsafeBitCast(symbol, to: T.self)
        }

        startup = resolve("TextToSpeechStartup", as: StartupFn.self)
        shutdown = resolve("TextToSpeechShutdown", as: ShutdownFn.self)
        openWaveOutFile = resolve("TextToSpeechOpenWaveOutFile", as: OpenWaveOutFileFn.self)
        closeWaveOutFile = resolve("TextToSpeechCloseWaveOutFile", as: CloseWaveOutFileFn.self)
        speak = resolve("TextToSpeechSpeak", as: SpeakFn.self)
        sync = resolve("TextToSpeechSync", as: SyncFn.self)
        setSpeaker = resolve("TextToSpeechSetSpeaker", as: SetSpeakerFn.self)

        if startup == nil || speak == nil {
            NSLog("DECtalk: failed to resolve required symbols from libtts.dylib")
        }
        return startup != nil && speak != nil
    }

    /// Synchronous by design: AVSpeechSynthesisProviderAudioUnit renders speech offline,
    /// so it's safe (and simplest) to block here rather than stream incrementally.
    func synthesize(text: String, speaker: UInt32) -> AVAudioPCMBuffer? {
        guard loadIfNeeded(),
              let engineDirectory,
              let startup, let shutdown, let openWaveOutFile,
              let closeWaveOutFile, let speak, let sync, let setSpeaker
        else { return nil }

        let fm = FileManager.default
        let previousDirectory = fm.currentDirectoryPath
        // DECtalk resolves DECtalk.conf and dic/*.dic relative to the process's cwd.
        fm.changeCurrentDirectoryPath(engineDirectory)
        defer { fm.changeCurrentDirectoryPath(previousDirectory) }

        var handle: UnsafeMutableRawPointer?
        guard startup(&handle, 0, 0, nil, 0) == 0, handle != nil else {
            NSLog("DECtalk: TextToSpeechStartup failed")
            return nil
        }
        defer { _ = shutdown(handle) }

        _ = setSpeaker(handle, speaker)

        let tempFile = fm.temporaryDirectory.appendingPathComponent("dectalk-\(UUID().uuidString).wav")
        defer { try? fm.removeItem(at: tempFile) }

        guard openWaveOutFile(handle, tempFile.path, 1) == 0 else {
            NSLog("DECtalk: TextToSpeechOpenWaveOutFile failed")
            return nil
        }

        text.withCString { _ = speak(handle, $0, 1) }
        _ = sync(handle)
        _ = closeWaveOutFile(handle)

        guard let file = try? AVAudioFile(forReading: tempFile) else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }

        guard buffer.format.channelCount > 1, let source = buffer.floatChannelData else {
            return buffer
        }

        // Downmix to mono in case the engine ever renders multi-channel output.
        guard let monoFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: buffer.format.sampleRate, channels: 1, interleaved: false),
              let mono = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: buffer.frameCapacity)
        else { return buffer }

        mono.frameLength = buffer.frameLength
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let destination = mono.floatChannelData![0]
        for frame in 0..<frameCount {
            var sum: Float = 0
            for channel in 0..<channelCount { sum += source[channel][frame] }
            destination[frame] = sum / Float(channelCount)
        }
        return mono
    }
}
