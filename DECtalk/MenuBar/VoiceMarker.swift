//
//  VoiceMarker.swift
//  DECtalk
//
//  Expands typed markers like <Paul> or <voice Harry> into DECtalk's
//  bracketed voice-select codes (e.g. [:np]) before text is spoken.
//

import Foundation

enum VoiceMarker {
    // The 9 built-in DECtalk voices and their single-letter [:nX] select
    // codes, per DECtalk's own docs ("DECtalk Voices and Their Associated
    // Values") — kept in sync with the 9 voices the AUv3 system-voice
    // extension exposes (DECtalkExtension/Common/Audio Unit/DECtalkEngine.swift).
    static let nameToCode: [String: String] = [
        "paul":   "[:np]",
        "betty":  "[:nb]",
        "harry":  "[:nh]",
        "frank":  "[:nf]",
        "dennis": "[:nd]",
        "kit":    "[:nk]",
        "ursula": "[:nu]",
        "rita":   "[:nr]",
        "wendy":  "[:nw]"
    ]

    static func completions() -> [String] {
        let names = ["Paul", "Betty", "Harry", "Frank", "Dennis", "Kit", "Ursula", "Rita", "Wendy"]
        var out: [String] = []
        for n in names { out.append("<\(n)>") }
        for n in names { out.append("<voice \(n)>") }
        return out
    }

    static func expandVoiceMarkersIfEnabled(_ input: String) -> String {
        let enabled = UserDefaults.standard.bool(forKey: PrefKeys.voiceMarkersEnabled)
        guard enabled else { return input }
        return expandVoiceMarkers(input)
    }

    private static func expandVoiceMarkers(_ input: String) -> String {
        let pattern = #"<\s*(?:voice\s+)?([A-Za-z]+)\s*>"#
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return input
        }

        let ns = input as NSString
        let matches = re.matches(in: input, options: [], range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return input }

        var out = ""
        var cursor = 0

        for m in matches {
            guard m.numberOfRanges >= 2 else { continue }

            let fullRange = m.range(at: 0)
            let nameRange = m.range(at: 1)

            if fullRange.location > cursor {
                out += ns.substring(with: NSRange(location: cursor, length: fullRange.location - cursor))
            }

            let rawName = ns.substring(with: nameRange).lowercased()
            if let code = nameToCode[rawName] {
                out += code
            } else {
                out += ns.substring(with: fullRange)
            }

            cursor = fullRange.location + fullRange.length
        }

        if cursor < ns.length {
            out += ns.substring(from: cursor)
        }

        return out
    }
}
