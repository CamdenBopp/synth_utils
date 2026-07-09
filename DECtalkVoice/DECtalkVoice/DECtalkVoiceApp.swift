//
//  DECtalkVoiceApp.swift
//  DECtalkVoice
//
//  This app's only real job is to exist as something the user launches
//  once so iOS registers the embedded DECtalkVoiceExtension — once
//  registered, the voices show up system-wide in Settings > Accessibility
//  > Spoken Content > Voices, and as selectable VoiceOver voices, without
//  this app needing to be open.
//

import SwiftUI

@main
struct DECtalkVoiceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
