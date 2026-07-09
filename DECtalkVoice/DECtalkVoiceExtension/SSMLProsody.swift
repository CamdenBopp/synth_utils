//
//  SSMLProsody.swift
//  DECtalkVoiceExtension
//
//  AVSpeechSynthesisProviderRequest has exactly two properties:
//  ssmlRepresentation and voice (confirmed against the AVFAudio SDK
//  header directly, not just docs) — there is no separate rate/pitch
//  field. VoiceOver's rate slider/rotor communicates its setting by
//  wrapping the utterance in SSML <prosody rate="X%">, so honoring it
//  means parsing that out of the SSML before stripping markup, not
//  reading some struct property that doesn't exist.
//

import Foundation

enum SSMLProsody {
    /// Returns the rate multiplier from the first <prosody rate="..."> in
    /// the SSML, or 1.0 (unchanged) if there isn't one / it can't be
    /// parsed. 100% (or "medium"/"default") == 1.0, per the SSML spec's
    /// "percentage is a multiplier of the voice's default rate" rule.
    static func rateMultiplier(in ssml: String) -> Double {
        guard let regex = try? NSRegularExpression(pattern: #"<prosody\b[^>]*\brate\s*=\s*"([^"]+)"[^>]*>"#, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: ssml, range: NSRange(ssml.startIndex..., in: ssml)),
              let range = Range(match.range(at: 1), in: ssml)
        else { return 1.0 }

        let value = ssml[range].trimmingCharacters(in: .whitespaces).lowercased()

        if value.hasSuffix("%"), let percent = Double(value.dropLast()) {
            return percent / 100.0
        }

        // SSML's named relative rates — values aren't standardized to an
        // exact number by the spec, these are reasonable, commonly-used
        // approximations.
        switch value {
        case "x-slow": return 0.5
        case "slow": return 0.75
        case "medium", "default": return 1.0
        case "fast": return 1.25
        case "x-fast": return 1.5
        default:
            // A bare number (no % or unit) is also valid SSML and means
            // the same multiplier as that percentage, e.g. rate="1.5".
            if let bare = Double(value) { return bare }
            return 1.0
        }
    }
}
