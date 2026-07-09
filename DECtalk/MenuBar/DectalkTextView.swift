//
//  DectalkTextView.swift
//  DECtalk
//
//  Text view that pops up voice-marker completions when typing "<".
//  NOTE: rangeForUserCompletion is a PROPERTY override, not a method.
//

import Cocoa

final class DectalkTextView: NSTextView {

    private func voiceAutocompleteEnabledNow() -> Bool {
        let markers = UserDefaults.standard.bool(forKey: PrefKeys.voiceMarkersEnabled)
        let completion = UserDefaults.standard.bool(forKey: PrefKeys.voiceAutocompleteEnabled)
        return markers && completion
    }

    override func keyDown(with event: NSEvent) {
        if voiceAutocompleteEnabledNow(),
           let chars = event.characters, chars == "<" {
            super.keyDown(with: event)
            DispatchQueue.main.async { self.complete(nil) }
            return
        }
        super.keyDown(with: event)
    }

    // Make completion treat "<Paul" as the "word" to complete.
    override var rangeForUserCompletion: NSRange {
        let sel = selectedRange()
        let loc = sel.location

        let ns = string as NSString
        guard loc <= ns.length else {
            return super.rangeForUserCompletion
        }

        let prefix = ns.substring(to: loc)

        guard let lastLessThan = prefix.lastIndex(of: "<") else {
            return super.rangeForUserCompletion
        }

        let idx = prefix.distance(from: prefix.startIndex, to: lastLessThan)

        // If there's already a ">" between "<" and cursor, don't treat it as a completion token.
        let tail = ns.substring(with: NSRange(location: idx, length: loc - idx))
        if tail.contains(">") {
            return super.rangeForUserCompletion
        }

        return NSRange(location: idx, length: loc - idx)
    }
}
