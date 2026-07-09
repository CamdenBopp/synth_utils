//
//  FocusModeDetector.swift
//  DECtalk
//
//  Heuristic Focus/Do Not Disturb detection: there's no public API for this,
//  so we read the same state files/defaults the system itself uses.
//

import Foundation

final class FocusModeDetector {

    struct FocusState {
        let isActive: Bool
        let currentMode: String?
    }

    func getCurrentFocusState() -> FocusState {
        let dndActive = checkDNDActive()
        let assertionsActive = checkFocusAssertions()
        let isActive = dndActive || assertionsActive

        return FocusState(
            isActive: isActive,
            currentMode: isActive ? detectCurrentModeName() : nil
        )
    }

    private func checkDNDActive() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["-currentHost", "read", "com.apple.notificationcenterui", "doNotDisturb"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "1"
        } catch {
            return false
        }
    }

    private func checkFocusAssertions() -> Bool {
        let assertionsPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/Assertions.json"

        guard FileManager.default.fileExists(atPath: assertionsPath),
              let data = FileManager.default.contents(atPath: assertionsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let storeData = json["data"] as? [[String: Any]] else {
            return false
        }

        return !storeData.isEmpty
    }

    private func detectCurrentModeName() -> String? {
        let configPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/ModeConfigurations.json"

        guard FileManager.default.fileExists(atPath: configPath),
              let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let configs = json["data"] as? [[String: Any]] else {
            return "Do Not Disturb"
        }

        for config in configs {
            if let name = config["name"] as? String {
                return name
            }
        }

        return "Focus"
    }

    func getAvailableFocusModes() -> [String] {
        var modes: [String] = ["Do Not Disturb"]

        let configPath = NSHomeDirectory() + "/Library/DoNotDisturb/DB/ModeConfigurations.json"

        guard FileManager.default.fileExists(atPath: configPath),
              let data = FileManager.default.contents(atPath: configPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let configs = json["data"] as? [[String: Any]] else {
            return modes
        }

        for config in configs {
            if let name = config["name"] as? String, !modes.contains(name) {
                modes.append(name)
            }
        }

        return modes
    }
}
