//
//  DECtalkApp.swift
//  DECtalk
//
//  Created by Camden Bopp on 12/4/25.
//

import Cocoa

// Plain AppKit entry point — NOT a SwiftUI App. Every window in this app
// (text input, preferences, AU validator) is AppKit-managed by
// MenuBarAppDelegate, and the SwiftUI App/Settings{} wrapper that was here
// before installed its own default main menu during scene setup, clobbering
// the delegate's custom menu (Close Window/Cmd+Q, the Speech menu) no
// matter when the delegate installed it. SwiftUI views (ContentView for the
// AU validator) still work fine via NSHostingController without the SwiftUI
// app lifecycle.
@main
struct DECtalkApp {
    // NSApplication.delegate is not a strong reference; keep the delegate
    // alive for the app's lifetime here.
    private static let appDelegate = MenuBarAppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
