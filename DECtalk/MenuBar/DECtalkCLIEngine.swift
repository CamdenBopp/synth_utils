//
//  DECtalkCLIEngine.swift
//  DECtalk
//
//  Runs the bundled DECtalk CLI tools (Resources/dectalk-dist/say, aclock)
//  as subprocesses rather than linking or dlopen'ing the engine directly —
//  this is a separate DECtalk build from the one the AUv3 speech extension
//  vendors (different binary sizes/ABI), so the two are kept independent.
//

import AVFoundation
import os

private let log = Logger(subsystem: "CamdenBopp.DECtalk", category: "DECtalkCLIEngine")

final class DECtalkCLIEngine {

    enum ToolError: Error, CustomStringConvertible {
        case emptyText
        case distNotFound
        case toolNotFound(tool: String)
        case toolNotExecutable(tool: String, path: String)
        case processFailed(tool: String, status: Int32, message: String)
        case noAudioWritten

        var description: String {
            switch self {
            case .emptyText:
                return "No text to speak."
            case .distNotFound:
                return "Bundled dectalk-dist folder not found."
            case .toolNotFound(let tool):
                return "Bundled tool not found: \(tool)"
            case .toolNotExecutable(let tool, let path):
                return "Bundled tool is not executable: \(tool) at \(path)"
            case .processFailed(let tool, let status, let message):
                let msg = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return msg.isEmpty ? "\(tool) failed (status \(status))." : "\(tool) failed (status \(status)): \(msg)"
            case .noAudioWritten:
                return "DECtalk produced no audio."
            }
        }
    }

    static let shared = DECtalkCLIEngine()

    private let distDirURL: URL?
    private let libDirURL: URL?
    private var audioPlayer: AVAudioPlayer?

    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }

    init() {
        guard let distURL = Bundle.main.url(forResource: "dectalk-dist", withExtension: nil) else {
            distDirURL = nil
            libDirURL = nil
            return
        }
        distDirURL = distURL
        libDirURL = distURL.appendingPathComponent("lib", isDirectory: true)
    }

    private func toolURL(_ name: String) throws -> URL {
        guard let distDirURL else { throw ToolError.distNotFound }
        let url = distDirURL.appendingPathComponent(name, isDirectory: false)
        let path = url.path

        guard FileManager.default.fileExists(atPath: path) else {
            throw ToolError.toolNotFound(tool: name)
        }
        guard FileManager.default.isExecutableFile(atPath: path) else {
            throw ToolError.toolNotExecutable(tool: name, path: path)
        }
        return url
    }

    private func makeEnv() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        guard let libDirURL else { return env }
        let libPath = libDirURL.path

        if let existing = env["DYLD_LIBRARY_PATH"], !existing.isEmpty {
            env["DYLD_LIBRARY_PATH"] = libPath + ":" + existing
        } else {
            env["DYLD_LIBRARY_PATH"] = libPath
        }
        return env
    }

    // DECtalk.conf and dic/*.dic are resolved by the tool relative to its
    // working directory, not to its own executable path — so every launch
    // must run with cwd set to the bundled dist folder. currentDirectoryURL
    // is per-Process (not a global chdir), so concurrent calls stay safe.
    private func runTool(name: String, arguments: [String]) throws -> (Int32, String) {
        let exeURL = try toolURL(name)

        let process = Process()
        process.executableURL = exeURL
        process.arguments = arguments
        process.environment = makeEnv()
        process.currentDirectoryURL = distDirURL

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = Pipe()

        log.notice("launching \(exeURL.path, privacy: .public) args=\(arguments, privacy: .public) cwd=\(self.distDirURL?.path ?? "nil", privacy: .public)")
        do {
            try process.run()
        } catch {
            log.error("process.run() THREW: \(String(describing: error), privacy: .public)")
            throw error
        }
        process.waitUntilExit()

        let status = process.terminationStatus
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let errStr = String(data: errData, encoding: .utf8) ?? ""
        log.notice("\(name, privacy: .public) exited status=\(status, privacy: .public) stderr=\(errStr, privacy: .public)")
        return (status, errStr)
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    func speakText(_ text: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.failure(ToolError.emptyText))
            return
        }

        let expanded = VoiceMarker.expandVoiceMarkersIfEnabled(trimmed)

        // say.c does an unbounded strcpy of the -fo path into a fixed stack
        // buffer and traps (SIGTRAP, _FORTIFY_SOURCE) past ~90-100 chars, so
        // the filename must stay short. A literal "/tmp/..." string is NOT
        // the same path for every party involved here: under App Sandbox,
        // this app's own FileManager calls transparently resolve "/tmp" to
        // this app's container (~/Library/Containers/<bundle-id>/Data/tmp),
        // but the child `say` process's raw C fopen() does not reliably
        // resolve a hardcoded "/tmp/..." string to that same location — so
        // the two ends can disagree about where the file actually is/was
        // written. Using FileManager's own temporaryDirectory keeps both
        // sides looking at the same, correctly-sandboxed path.
        let shortID = UUID().uuidString.prefix(8)
        let wavURL = FileManager.default.temporaryDirectory.appendingPathComponent("dt-\(shortID).wav")

        try? FileManager.default.removeItem(at: wavURL)

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (status, errStr) = try self.runTool(
                    name: "say",
                    arguments: ["-e", "1", "-fo", wavURL.path, "-a", expanded]
                )

                if status != 0 {
                    DispatchQueue.main.async {
                        completion(.failure(ToolError.processFailed(tool: "say", status: status, message: errStr)))
                    }
                    return
                }

                guard FileManager.default.fileExists(atPath: wavURL.path) else {
                    log.error("no file at \(wavURL.path, privacy: .public) after say exited status=0")
                    DispatchQueue.main.async { completion(.failure(ToolError.noAudioWritten)) }
                    return
                }

                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: wavURL.path)
                    let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
                    log.notice("\(wavURL.path, privacy: .public) size=\(size, privacy: .public)")
                    if size <= 0 {
                        DispatchQueue.main.async { completion(.failure(ToolError.noAudioWritten)) }
                        return
                    }
                } catch {
                    log.error("attributesOfItem threw: \(String(describing: error), privacy: .public)")
                    // Still attempt playback
                }

                DispatchQueue.main.async {
                    do {
                        let player = try AVAudioPlayer(contentsOf: wavURL)
                        player.prepareToPlay()
                        self.audioPlayer = player
                        player.play()
                        completion(.success(()))
                    } catch {
                        completion(.failure(error))
                    }
                }

            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func runAClock(completion: @escaping (Result<Void, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let (status, errStr) = try self.runTool(name: "aclock", arguments: [])
                if status != 0 {
                    DispatchQueue.main.async {
                        completion(.failure(ToolError.processFailed(tool: "aclock", status: status, message: errStr)))
                    }
                    return
                }
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}
