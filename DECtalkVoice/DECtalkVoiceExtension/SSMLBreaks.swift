//
//  SSMLBreaks.swift
//  DECtalkVoiceExtension
//
//  VoiceOver communicates hint pauses (and any other authored pause) via
//  SSML <break time="500ms"/> — there's no separate "pause here" field on
//  AVSpeechSynthesisProviderRequest, same story as <prosody rate="..."> in
//  SSMLProsody.swift. DECtalk's own text engine has no concept of a pause
//  duration, so this splits the SSML into text/pause segments up front;
//  the audio unit synthesizes each text run separately and splices in real
//  silence for each pause when it stitches the segments back together.
//

import Foundation

enum SSMLSegment {
    case text(String)
    case pause(TimeInterval)
}

enum SSMLBreaks {
    private static let breakTagPattern = #"<break\b([^>]*)>"#

    /// Splits raw SSML into an ordered sequence of text runs and pauses.
    /// Text runs may still contain other SSML tags (e.g. <prosody>) —
    /// stripping those is the caller's job, same as before this existed.
    static func segment(_ ssml: String) -> [SSMLSegment] {
        guard let regex = try? NSRegularExpression(pattern: breakTagPattern, options: [.caseInsensitive]) else {
            return [.text(ssml)]
        }

        let ns = ssml as NSString
        let matches = regex.matches(in: ssml, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return [.text(ssml)] }

        var segments: [SSMLSegment] = []
        var cursor = 0

        for match in matches {
            let fullRange = match.range(at: 0)
            if fullRange.location > cursor {
                segments.append(.text(ns.substring(with: NSRange(location: cursor, length: fullRange.location - cursor))))
            }

            let attrsRange = match.range(at: 1)
            let attrs = attrsRange.location != NSNotFound ? ns.substring(with: attrsRange) : ""
            segments.append(.pause(duration(fromBreakAttributes: attrs)))

            cursor = fullRange.location + fullRange.length
        }

        if cursor < ns.length {
            segments.append(.text(ns.substring(from: cursor)))
        }

        return segments
    }

    private static func duration(fromBreakAttributes attrs: String) -> TimeInterval {
        if let value = attributeValue("time", in: attrs) {
            if value.hasSuffix("ms"), let ms = Double(value.dropLast(2)) {
                return max(0, ms / 1000.0)
            }
            if value.hasSuffix("s"), let s = Double(value.dropLast(1)) {
                return max(0, s)
            }
        }

        // <break strength="..."/> is valid SSML too (no time attribute at
        // all). The spec doesn't pin these to exact durations — these are
        // the same approximate values common TTS engines use.
        if let strength = attributeValue("strength", in: attrs) {
            switch strength {
            case "none": return 0
            case "x-weak": return 0.1
            case "weak": return 0.25
            case "medium": return 0.5
            case "strong": return 0.75
            case "x-strong": return 1.0
            default: break
            }
        }

        // Bare <break/> with no attributes: SSML's implied default is a
        // "medium" pause.
        return 0.5
    }

    private static func attributeValue(_ name: String, in attrs: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "\\b\(name)\\s*=\\s*\"([^\"]+)\"", options: [.caseInsensitive]),
              let match = regex.firstMatch(in: attrs, range: NSRange(attrs.startIndex..., in: attrs)),
              let range = Range(match.range(at: 1), in: attrs)
        else { return nil }
        return attrs[range].trimmingCharacters(in: .whitespaces).lowercased()
    }
}
