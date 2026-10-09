//
//  DECtalkVoice.swift
//  DECtalkVoiceExtension
//
//  The 9 built-in DECtalk voices and their classic embedded [:nX]
//  voice-select codes, per DECtalk's own docs ("DECtalk Voices and Their
//  Associated Values") — verified against this specific engine build by
//  rendering identical text through all 9 and confirming distinct output.
//

import Foundation

enum DECtalkVoice: String, CaseIterable {
    case paul, betty, harry, frank, dennis, kit, ursula, rita, wendy

    var markupCode: String {
        switch self {
        case .paul: return "[:np]"
        case .betty: return "[:nb]"
        case .harry: return "[:nh]"
        case .frank: return "[:nf]"
        case .dennis: return "[:nd]"
        case .kit: return "[:nk]"
        case .ursula: return "[:nu]"
        case .rita: return "[:nr]"
        case .wendy: return "[:nw]"
        }
    }

    var identifier: String { "CamdenBopp.DECtalkVoice.\(rawValue)" }
    var displayName: String { "DECtalk \(rawValue.capitalized)" }

    static func from(identifier: String) -> DECtalkVoice {
        let key = identifier.split(separator: ".").last.map(String.init) ?? ""
        return DECtalkVoice(rawValue: key) ?? .paul
    }
}
