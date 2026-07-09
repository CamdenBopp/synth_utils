//
//  PrefKeys.swift
//  DECtalk
//
//  UserDefaults keys and shared preference-driven types for the menu bar app.
//

import Foundation

struct PrefKeys {
    static let clockEnabled = "clockEnabled"
    static let clockInterval = "clockIntervalMinutes"
    static let focusBehavior = "focusBehavior"
    static let allowedFocusModes = "allowedFocusModes"

    static let voiceMarkersEnabled = "voiceMarkersEnabled"
    static let voiceAutocompleteEnabled = "voiceAutocompleteEnabled"
}

enum FocusBehavior: Int, CaseIterable {
    case ignoreAllFocus = 0
    case silenceOnAnyFocus = 1
    case allowSpecificFocus = 2

    var displayName: String {
        switch self {
        case .ignoreAllFocus: return "Ignore Focus Modes"
        case .silenceOnAnyFocus: return "Silence During Any Focus"
        case .allowSpecificFocus: return "Only During Specific Focus Modes"
        }
    }
}
